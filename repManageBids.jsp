<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require REP or ADMIN login
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
    String bidderName = request.getParameter("bidder");
    String minBidStr = request.getParameter("min_bid");
    String maxBidStr = request.getParameter("max_bid");

    //Handle delete_bid action (delete ONE specific bid)
    if ("delete_bid".equals(action)) {
        String delAuctionStr = request.getParameter("del_auction_id");
        String delBidderIdStr= request.getParameter("del_bidder_id");
        String delAmtStr     = request.getParameter("del_bid_amount");
        String delTimeStr    = request.getParameter("del_bid_time"); // timestamp string

        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
            int delAuctionId = Integer.parseInt(delAuctionStr);
            int delBidderId  = Integer.parseInt(delBidderIdStr);
            double delAmount = Double.parseDouble(delAmtStr);

            // Parse the timestamp string back to java.sql.Timestamp
            Timestamp delTime = Timestamp.valueOf(delTimeStr);

            String delSql =
              "DELETE FROM bids " +
              "WHERE auction_id=? AND bidder_id=? AND bid_amount=? AND bid_time=? LIMIT 1";

            try (PreparedStatement ps = c.prepareStatement(delSql)) {
                ps.setInt(1, delAuctionId);
                ps.setInt(2, delBidderId);
                ps.setDouble(3, delAmount);
                ps.setTimestamp(4, delTime);
                int rows = ps.executeUpdate();
                if (rows > 0) {
                    msg = "Bid removed successfully.";
                } else {
                    msg = "No matching bid found to delete (it may have already been removed).";
                }
            }
        } catch (Exception e) {
            msg = "Error deleting bid: " + e.getMessage();
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Rep – Manage Bids</title>
</head>
<body>
  <h2>Rep – Manage Bids</h2>
  <p>Logged in as <strong><%= username %></strong> (<%= role %>)</p>

<% if (msg != null) { %>
  <p style="color:blue;"><%= msg %></p>
<% } %>

  <h3>Search Bids</h3>
  <form method="get" action="repManageBids.jsp">
    <label>Auction ID:
      <input type="text" name="auction_id"
             value="<%= (auctionStr == null ? "" : auctionStr) %>">
    </label>
    &nbsp;
    <label>Bidder username:
      <input type="text" name="bidder"
             value="<%= (bidderName == null ? "" : bidderName) %>">
    </label>
    <br/><br/>
    <label>Min bid amount:
      <input type="text" name="min_bid"
             value="<%= (minBidStr == null ? "" : minBidStr) %>">
    </label>
    &nbsp;
    <label>Max bid amount:
      <input type="text" name="max_bid"
             value="<%= (maxBidStr == null ? "" : maxBidStr) %>">
    </label>
    &nbsp;
    <button type="submit">Search</button>
  </form>

  <hr/>

  <h3>Matching Bids</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Auction ID</th>
      <th>Title</th>
      <th>Bidder</th>
      <th>Bid Amount</th>
      <th>Bid Time</th>
      <th>Actions</th>
    </tr>
<%
    //If no filters at all, we can choose to show nothing until user searches
    boolean anyFilter =
        (auctionStr != null && !auctionStr.trim().isEmpty()) ||
        (bidderName != null && !bidderName.trim().isEmpty()) ||
        (minBidStr != null && !minBidStr.trim().isEmpty()) ||
        (maxBidStr != null && !maxBidStr.trim().isEmpty());

    if (!anyFilter) {
%>
    <tr><td colspan="6"><em>Enter a filter above and click Search to see bids.</em></td></tr>
<%
    } else {
        StringBuilder sql = new StringBuilder(
          "SELECT b.auction_id, b.bidder_id, b.bid_amount, b.bid_time, " +
          "a.title, u.username " +
          "FROM bids b " +
          "JOIN auctions a ON b.auction_id = a.auction_id " +
          "JOIN users u ON b.bidder_id = u.user_id " +
          "WHERE 1=1 "
        );

        java.util.List<Object> params = new java.util.ArrayList<>();

        if (auctionStr != null && !auctionStr.trim().isEmpty()) {
            sql.append(" AND b.auction_id = ? ");
            params.add(Integer.parseInt(auctionStr.trim()));
        }
        if (bidderName != null && !bidderName.trim().isEmpty()) {
            sql.append(" AND u.username LIKE ? ");
            params.add("%" + bidderName.trim() + "%");
        }
        if (minBidStr != null && !minBidStr.trim().isEmpty()) {
            sql.append(" AND b.bid_amount >= ? ");
            params.add(Double.parseDouble(minBidStr.trim()));
        }
        if (maxBidStr != null && !maxBidStr.trim().isEmpty()) {
            sql.append(" AND b.bid_amount <= ? ");
            params.add(Double.parseDouble(maxBidStr.trim()));
        }

        sql.append(" ORDER BY b.bid_time DESC LIMIT 200 ");

        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
             PreparedStatement ps = c.prepareStatement(sql.toString())) {

            int idx = 1;
            for (Object p : params) {
                if (p instanceof Integer) ps.setInt(idx++, (Integer)p);
                else if (p instanceof Double) ps.setDouble(idx++, (Double)p);
                else ps.setString(idx++, (String)p);
            }

            try (ResultSet rs = ps.executeQuery()) {
                boolean any = false;
                while (rs.next()) {
                    any = true;
                    int aId     = rs.getInt("auction_id");
                    int bidderId= rs.getInt("bidder_id");
                    double amt  = rs.getDouble("bid_amount");
                    Timestamp bt= rs.getTimestamp("bid_time");
%>
    <tr>
      <td><%= aId %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= rs.getString("username") %></td>
      <td><%= amt %></td>
      <td><%= bt %></td>
      <td>
        <form method="post" action="repManageBids.jsp"
              onsubmit="return confirm('Delete this bid?');"
              style="display:inline;">
          <input type="hidden" name="action" value="delete_bid">
          <input type="hidden" name="del_auction_id" value="<%= aId %>">
          <input type="hidden" name="del_bidder_id" value="<%= bidderId %>">
          <input type="hidden" name="del_bid_amount" value="<%= amt %>">
          <input type="hidden" name="del_bid_time" value="<%= bt %>">
          <button type="submit">Delete bid</button>
        </form>
      </td>
    </tr>
<%
                }
                if (!any) {
%>
    <tr><td colspan="6"><em>No bids matched the filters.</em></td></tr>
<%
                }
            }
        } catch (Exception e) {
%>
    <tr><td colspan="6">Error loading bids: <%= e.getMessage() %></td></tr>
<%
        }
    } // end else
%>
  </table>

  <p>
    <a href="repDashboard.jsp">Rep dashboard</a> |
    <a href="home.jsp">Home</a>
  </p>

</body>
</html>