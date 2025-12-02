<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require auction_id parameter
    String idStr = request.getParameter("auction_id");
    if (idStr == null) {
        out.println("No auction_id provided.");
        return;
    }

    int auctionId = -1;
    try {
        auctionId = Integer.parseInt(idStr);
    } catch (NumberFormatException nfe) {
        out.println("Invalid auction_id.");
        return;
    }

    //Load db properties
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");

    String title = null;
    String sellerName = null;
    boolean auctionExists = false;
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Bid History</title>
</head>
<body>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {

        //Load basic auction info
        try (PreparedStatement ps = c.prepareStatement(
             "SELECT a.title, u.username AS seller_name " +
             "FROM auctions a JOIN users u ON a.seller_id = u.user_id " +
             "WHERE a.auction_id = ?")) {

            ps.setInt(1, auctionId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    auctionExists = true;
                    title = rs.getString("title");
                    sellerName = rs.getString("seller_name");
                }
            }
        }

        if (!auctionExists) {
%>
  <p>Auction not found.</p>
  <p><a href="home.jsp">Back to home</a></p>
<%
        } else {
%>
  <h2>Bid History for Auction #<%= auctionId %></h2>
  <p><strong>Title:</strong> <%= title %></p>
  <p><strong>Seller:</strong> <%= sellerName %></p>
  <hr/>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Bid ID</th>
      <th>Bidder</th>
      <th>Amount</th>
      <th>Time</th>
    </tr>
<%
            //Load bids
            try (PreparedStatement ps = c.prepareStatement(
                 "SELECT b.bid_id, b.bid_amount, b.bid_time, u.username " +
                 "FROM bids b JOIN users u ON b.bidder_id = u.user_id " +
                 "WHERE b.auction_id = ? " +
                 "ORDER BY b.bid_time DESC")) {

                ps.setInt(1, auctionId);
                try (ResultSet rs = ps.executeQuery()) {
                    boolean any = false;
                    while (rs.next()) {
                        any = true;
%>
    <tr>
      <td><%= rs.getInt("bid_id") %></td>
      <td><%= rs.getString("username") %></td>
      <td><%= rs.getBigDecimal("bid_amount") %></td>
      <td><%= rs.getTimestamp("bid_time") %></td>
    </tr>
<%
                    }
                    if (!any) {
%>
    <tr>
      <td colspan="4"><em>No bids yet for this auction.</em></td>
    </tr>
<%
                    }
                }
            }
%>
  </table>

  <p>
    <a href="viewAuction.jsp?auction_id=<%= auctionId %>">Back to auction</a> |
    <a href="home.jsp">Back to home</a>
  </p>
<%
        } // end auctionExists
    } catch (Exception e) {
%>
  <p>Error loading bid history: <%= e.getMessage() %></p>
<%
    }
%>
</body>
</html>