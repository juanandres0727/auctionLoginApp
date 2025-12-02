<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream,java.math.BigDecimal" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    // Require ADMIN only 
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || role == null || !"ADMIN".equals(role)) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }

    // Load DB props
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");
    Class.forName("com.mysql.cj.jdbc.Driver");

    String globalError = null;
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Maintenance — Close Expired Auctions</title>
</head>
<body>
  <h2>Maintenance — Close Expired Auctions</h2>
  <p>Logged in as <strong><%= username %></strong> (ADMIN)</p>

<%
    try (Connection conn = DriverManager.getConnection(url, dbUser, dbPass)) {

        //Find all OPEN auctions whose end_time is in the past (expired)
        String selectSql =
            "SELECT auction_id, title, status, current_price, reserve_price, end_time " +
            "FROM auctions " +
            "WHERE status = 'OPEN' " +
            "AND end_time <= NOW() " +
            "ORDER BY end_time ASC";

        try (PreparedStatement ps = conn.prepareStatement(selectSql);
             ResultSet rs = ps.executeQuery()) {

%>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Auction ID</th>
      <th>Title</th>
      <th>Old Status</th>
      <th>New Status</th>
      <th>Final Price</th>
      <th>Note</th>
    </tr>
<%
            boolean any = false;

            while (rs.next()) {
                any = true;

                int auctionId          = rs.getInt("auction_id");
                String title           = rs.getString("title");
                String oldStatus       = rs.getString("status");
                BigDecimal curPrice    = rs.getBigDecimal("current_price");
                BigDecimal reserve     = rs.getBigDecimal("reserve_price");
                Timestamp endTime      = rs.getTimestamp("end_time");

                //Find highest bid (if any)
                BigDecimal highestBid = null;
                try (PreparedStatement ps2 = conn.prepareStatement(
                     "SELECT MAX(bid_amount) AS max_bid " +
                     "FROM bids WHERE auction_id = ?")) {
                    ps2.setInt(1, auctionId);
                    try (ResultSet rs2 = ps2.executeQuery()) {
                        if (rs2.next()) {
                            highestBid = rs2.getBigDecimal("max_bid");
                        }
                    }
                }

                String newStatus = "CLOSED";
                String note;
                BigDecimal finalPrice = curPrice;

                if (highestBid == null) {
                    // No bids at all
                    note = "Closed: no bids";
                    // You can choose: finalPrice = curPrice or 0; we keep current_price as-is
                } else {
                    // There was at least one bid
                    finalPrice = highestBid;
                    if (reserve != null && highestBid.compareTo(reserve) >= 0) {
                        note = "Closed: sold (reserve met)";
                    } else {
                        note = "Closed: reserve not met";
                    }
                }

                //Update auction row
                try (PreparedStatement upd = conn.prepareStatement(
                     "UPDATE auctions SET status = ?, current_price = ? WHERE auction_id = ?")) {
                    upd.setString(1, newStatus);
                    upd.setBigDecimal(2, finalPrice);
                    upd.setInt(3, auctionId);
                    upd.executeUpdate();
                }
%>
    <tr>
      <td><%= auctionId %></td>
      <td><%= title %></td>
      <td><%= oldStatus %></td>
      <td><%= newStatus %></td>
      <td><%= finalPrice %></td>
      <td><%= note %></td>
    </tr>
<%
            } // end while

            if (!any) {
%>
    <tr>
      <td colspan="6"><em>No expired OPEN auctions were found.</em></td>
    </tr>
<%
            }
%>
  </table>
<%
        } catch (Exception e) {
            globalError = "Error during maintenance: " + e.getMessage();
        }

    } catch (Exception e) {
        globalError = "Error connecting to DB: " + e.getMessage();
    }

    if (globalError != null) {
%>
  <p style="color:red;"><%= globalError %></p>
<%
    }
%>

  <p>
    <a href="adminDashboard.jsp">Admin Dashboard</a> |
    <a href="repDashboard.jsp">REP Dashboard</a> |
    <a href="home.jsp">Home</a>
  </p>
</body>
</html>