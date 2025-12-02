<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require login
    Integer userIdObj = (Integer) session.getAttribute("user_id");
    String username   = (String) session.getAttribute("username");
    if (userIdObj == null || username == null) {
        response.sendRedirect("index.jsp?msg=Please+login");
        return;
    }
    int userId = userIdObj;

    //Load db props
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>My History</title>
</head>
<body>
  <h2>History for <%= username %></h2>

  <!-- 1. Auctions I'm selling -->
  <h3>Auctions I am selling</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Title</th>
      <th>Status</th>
      <th>Current Price</th>
      <th>Ends</th>
      <th>View</th>
    </tr>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT auction_id, title, status, current_price, end_time " +
           "FROM auctions WHERE seller_id = ? ORDER BY end_time DESC")) {

        ps.setInt(1, userId);
        try (ResultSet rs = ps.executeQuery()) {
            boolean any = false;
            while (rs.next()) {
                any = true;
%>
    <tr>
      <td><%= rs.getInt("auction_id") %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= rs.getString("status") %></td>
      <td><%= rs.getBigDecimal("current_price") %></td>
      <td><%= rs.getTimestamp("end_time") %></td>
      <td><a href="viewAuction.jsp?auction_id=<%= rs.getInt("auction_id") %>">View</a></td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="6"><em>You are not selling any items yet.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="6">Error: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <!-- 2. Auctions I've bid on -->
  <h3>Auctions I have bid on</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Auction ID</th>
      <th>Title</th>
      <th>Status</th>
      <th>Highest Bid</th>
      <th>Highest Bidder</th>
      <th>My Last Bid</th>
      <th>Outcome</th>
      <th>View</th>
    </tr>
<%
    String sql =
      "SELECT DISTINCT a.auction_id, a.title, a.status, a.end_time, " +
      "(SELECT MAX(b2.bid_amount) FROM bids b2 WHERE b2.auction_id = a.auction_id) AS highest_bid, " +
      "(SELECT u2.username " +
      "FROM bids b3 JOIN users u2 ON b3.bidder_id = u2.user_id " +
      "WHERE b3.auction_id = a.auction_id " +
      "ORDER BY b3.bid_amount DESC, b3.bid_time DESC LIMIT 1) AS highest_bidder, " +
      "(SELECT b4.bid_amount " +
      "FROM bids b4 " +
      "WHERE b4.auction_id = a.auction_id AND b4.bidder_id = ? " +
      "ORDER BY b4.bid_time DESC LIMIT 1) AS my_last_bid " +
      "FROM auctions a " +
      "JOIN bids b ON a.auction_id = b.auction_id " +
      "WHERE b.bidder_id = ? " +
      "ORDER BY a.end_time DESC";

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(sql)) {

        ps.setInt(1, userId); // for my_last_bid subquery
        ps.setInt(2, userId); // for main WHERE

        try (ResultSet rs = ps.executeQuery()) {
            boolean any2 = false;
            while (rs.next()) {
                any2 = true;
                String aStatus = rs.getString("status");
                String highestBidder = rs.getString("highest_bidder");
                java.math.BigDecimal highestBid = rs.getBigDecimal("highest_bid");
                java.math.BigDecimal myLastBid = rs.getBigDecimal("my_last_bid");

                String outcome;
                if ("CLOSED".equals(aStatus)) {
                    if (highestBidder != null && highestBidder.equals(username)) {
                        outcome = "I WON";
                    } else {
                        outcome = "Closed (I did not win)";
                    }
                } else if ("OPEN".equals(aStatus)) {
                    if (highestBidder != null && highestBidder.equals(username)) {
                        outcome = "Currently winning";
                    } else {
                        outcome = "Outbid or not highest";
                    }
                } else {
                    outcome = aStatus;
                }
%>
    <tr>
      <td><%= rs.getInt("auction_id") %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= aStatus %></td>
      <td><%= highestBid %></td>
      <td><%= highestBidder %></td>
      <td><%= myLastBid %></td>
      <td><%= outcome %></td>
      <td><a href="viewAuction.jsp?auction_id=<%= rs.getInt("auction_id") %>">View</a></td>
    </tr>
<%
            }
            if (!any2) {
%>
    <tr><td colspan="8"><em>You haven’t bid on any auctions yet.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="8">Error: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p><a href="home.jsp">Back to home</a></p>
</body>
</html>