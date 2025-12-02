<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require rep or admin login
    String role     = (String) session.getAttribute("role");
    String username = (String) session.getAttribute("username");
    if (role == null || username == null || (!"REP".equals(role) && !"ADMIN".equals(role))) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }

    //Load DB props
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");

    request.setCharacterEncoding("UTF-8");

    String action = request.getParameter("action");
    String msg = null;
    String auctionStr = request.getParameter("auction_id");
    String sellerName = request.getParameter("seller");
    String statusFilter = request.getParameter("status"); // OPEN/CLOSED or blank

    //Handle close_now / remove_auction actions
    if (action != null && request.getParameter("target_auction_id") != null) {
        String targetStr = request.getParameter("target_auction_id");
        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
            int targetId = Integer.parseInt(targetStr);

            if ("close_now".equals(action)) {
                String sql =
                  "UPDATE auctions SET status='CLOSED', end_time=NOW() WHERE auction_id=?";
                try (PreparedStatement ps = c.prepareStatement(sql)) {
                    ps.setInt(1, targetId);
                    int rows = ps.executeUpdate();
                    if (rows > 0) msg = "Auction #" + targetId + " closed.";
                    else          msg = "Auction not found or already closed.";
                }
            } else if ("remove_auction".equals(action)) {
                //Interpret "remove" as: delete all bids and close auction
                c.setAutoCommit(false);
                try {
                    try (PreparedStatement ps = c.prepareStatement(
                         "DELETE FROM bids WHERE auction_id=?")) {
                        ps.setInt(1, targetId);
                        ps.executeUpdate();
                    }
                    try (PreparedStatement ps = c.prepareStatement(
                         "UPDATE auctions SET status='CLOSED', end_time=NOW() WHERE auction_id=?")) {
                        ps.setInt(1, targetId);
                        ps.executeUpdate();
                    }
                    c.commit();
                    msg = "Auction #" + targetId + " closed and all bids removed (treated as removed/illegal).";
                } catch (Exception ex) {
                    c.rollback();
                    msg = "Error removing auction: " + ex.getMessage();
                }
            }
        } catch (Exception e) {
            msg = "Error performing action: " + e.getMessage();
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Rep – Manage Auctions</title>
</head>
<body>
  <h2>Rep – Manage Auctions</h2>
  <p>Logged in as <strong><%= username %></strong> (<%= role %>)</p>

<% if (msg != null) { %>
  <p style="color:blue;"><%= msg %></p>
<% } %>

  <h3>Search Auctions</h3>
  <form method="get" action="repManageAuctions.jsp">
    <label>Auction ID:
      <input type="text" name="auction_id"
             value="<%= (auctionStr == null ? "" : auctionStr) %>">
    </label>
    &nbsp;
    <label>Seller username:
      <input type="text" name="seller"
             value="<%= (sellerName == null ? "" : sellerName) %>">
    </label>
    &nbsp;
    <label>Status:
      <select name="status">
        <option value="" <%= (statusFilter == null || statusFilter.isEmpty()) ? "selected" : "" %>>
          (any)
        </option>
        <option value="OPEN" <%= "OPEN".equals(statusFilter) ? "selected" : "" %>>OPEN</option>
        <option value="CLOSED" <%= "CLOSED".equals(statusFilter) ? "selected" : "" %>>CLOSED</option>
      </select>
    </label>
    &nbsp;
    <button type="submit">Search</button>
  </form>

  <hr/>

  <h3>Matching Auctions</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Title</th>
      <th>Seller</th>
      <th>Status</th>
      <th>Current Price</th>
      <th>End Time</th>
      <th>Actions</th>
    </tr>
<%
    boolean anyFilter =
        (auctionStr != null && !auctionStr.trim().isEmpty()) ||
        (sellerName != null && !sellerName.trim().isEmpty()) ||
        (statusFilter != null && !statusFilter.trim().isEmpty());

    if (!anyFilter) {
%>
    <tr><td colspan="7"><em>Enter a filter above and click Search to see auctions.</em></td></tr>
<%
    } else {
        StringBuilder sql = new StringBuilder(
          "SELECT a.auction_id, a.title, a.status, a.current_price, a.end_time, " +
          "u.username AS seller_name " +
          "FROM auctions a " +
          "JOIN users u ON a.seller_id = u.user_id " +
          "WHERE 1=1 "
        );

        java.util.List<Object> params = new java.util.ArrayList<>();

        if (auctionStr != null && !auctionStr.trim().isEmpty()) {
            sql.append(" AND a.auction_id = ? ");
            params.add(Integer.parseInt(auctionStr.trim()));
        }
        if (sellerName != null && !sellerName.trim().isEmpty()) {
            sql.append(" AND u.username LIKE ? ");
            params.add("%" + sellerName.trim() + "%");
        }
        if (statusFilter != null && !statusFilter.trim().isEmpty()) {
            sql.append(" AND a.status = ? ");
            params.add(statusFilter.trim());
        }

        sql.append(" ORDER BY a.end_time DESC LIMIT 200 ");

        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
             PreparedStatement ps = c.prepareStatement(sql.toString())) {

            int idx = 1;
            for (Object p : params) {
                if (p instanceof Integer) ps.setInt(idx++, (Integer)p);
                else ps.setString(idx++, (String)p);
            }

            try (ResultSet rs = ps.executeQuery()) {
                boolean any = false;
                while (rs.next()) {
                    any = true;
                    int aId = rs.getInt("auction_id");
%>
    <tr>
      <td><%= aId %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= rs.getString("seller_name") %></td>
      <td><%= rs.getString("status") %></td>
      <td><%= rs.getBigDecimal("current_price") %></td>
      <td><%= rs.getTimestamp("end_time") %></td>
      <td>
        <!-- Close now -->
        <form method="post" action="repManageAuctions.jsp"
              style="display:inline;"
              onsubmit="return confirm('Close this auction now?');">
          <input type="hidden" name="action" value="close_now">
          <input type="hidden" name="target_auction_id" value="<%= aId %>">
          <button type="submit">Close now</button>
        </form>

        <!-- Remove auction (close + delete bids) -->
        <form method="post" action="repManageAuctions.jsp"
              style="display:inline;"
              onsubmit="return confirm('Close this auction and remove all bids? This cannot be undone.');">
          <input type="hidden" name="action" value="remove_auction">
          <input type="hidden" name="target_auction_id" value="<%= aId %>">
          <button type="submit">Remove auction</button>
        </form>
      </td>
    </tr>
<%
                }
                if (!any) {
%>
    <tr><td colspan="7"><em>No auctions matched the filters.</em></td></tr>
<%
                }
            }
        } catch (Exception e) {
%>
    <tr><td colspan="7">Error loading auctions: <%= e.getMessage() %></td></tr>
<%
        }
    }
%>
  </table>

  <p>
    <a href="repDashboard.jsp">Rep dashboard</a> |
    <a href="home.jsp">Home</a>
  </p>

</body>
</html>