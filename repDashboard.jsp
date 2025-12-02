<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require rep login
    String username = (String) session.getAttribute("username");
    String role     = (String) session.getAttribute("role");
    Integer userIdObj = (Integer) session.getAttribute("user_id");

    if (username == null || role == null || !role.equals("REP")) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }
    int repId = userIdObj;

    //Load DB properties
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");

    String action = request.getParameter("action");
    String msg    = null;

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
        c.setAutoCommit(false);

        if ("close_auction".equals(action)) {
            String aidStr = request.getParameter("auction_id");
            try {
                int auctionId = Integer.parseInt(aidStr);

                // Set status to CLOSED
                try (PreparedStatement ps = c.prepareStatement(
                     "UPDATE auctions SET status='CLOSED' WHERE auction_id=? AND status='OPEN'")) {
                    ps.setInt(1, auctionId);
                    int updated = ps.executeUpdate();
                    if (updated > 0) {
                        msg = "Auction " + auctionId + " closed.";
                    } else {
                        msg = "Auction not found or not OPEN.";
                    }
                }
                c.commit();
            } catch (Exception e) {
                c.rollback();
                msg = "Error closing auction: " + e.getMessage();
            }

        } else if ("cancel_auction".equals(action)) {
            String aidStr = request.getParameter("auction_id");
            try {
                int auctionId = Integer.parseInt(aidStr);

                // Set status to CANCELLED
                try (PreparedStatement ps = c.prepareStatement(
                     "UPDATE auctions SET status='CANCELLED' WHERE auction_id=? AND status='OPEN'")) {
                    ps.setInt(1, auctionId);
                    int updated = ps.executeUpdate();
                    if (updated > 0) {
                        msg = "Auction " + auctionId + " cancelled.";
                    } else {
                        msg = "Auction not found or not OPEN.";
                    }
                }
                c.commit();
            } catch (Exception e) {
                c.rollback();
                msg = "Error cancelling auction: " + e.getMessage();
            }

        } else if ("remove_bid".equals(action)) {
            String bidStr = request.getParameter("bid_id");
            try {
                int bidId = Integer.parseInt(bidStr);

                //Find the auction and the bid amount to delete
                int auctionId = -1;
                double removedAmount = 0.0;
                try (PreparedStatement ps = c.prepareStatement(
                     "SELECT auction_id, bid_amount FROM bids WHERE bid_id=?")) {
                    ps.setInt(1, bidId);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            auctionId     = rs.getInt("auction_id");
                            removedAmount = rs.getDouble("bid_amount");
                        }
                    }
                }

                if (auctionId == -1) {
                    msg = "Bid not found.";
                } else {
                    //Delete the bid
                    try (PreparedStatement ps = c.prepareStatement(
                         "DELETE FROM bids WHERE bid_id=?")) {
                        ps.setInt(1, bidId);
                        ps.executeUpdate();
                    }

                    //Recompute current_price for that auction
                    double startPrice = 0.0;
                    try (PreparedStatement ps = c.prepareStatement(
                         "SELECT start_price FROM auctions WHERE auction_id=?")) {
                        ps.setInt(1, auctionId);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) {
                                startPrice = rs.getDouble("start_price");
                            }
                        }
                    }

                    double newPrice = startPrice;

                    try (PreparedStatement ps = c.prepareStatement(
                         "SELECT MAX(bid_amount) AS max_bid FROM bids WHERE auction_id=?")) {
                        ps.setInt(1, auctionId);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next() && rs.getBigDecimal("max_bid") != null) {
                                newPrice = rs.getDouble("max_bid");
                            }
                        }
                    }

                    try (PreparedStatement ps = c.prepareStatement(
                         "UPDATE auctions SET current_price=? WHERE auction_id=?")) {
                        ps.setDouble(1, newPrice);
                        ps.setInt(2, auctionId);
                        ps.executeUpdate();
                    }

                    msg = "Bid " + bidId + " removed. Auction " + auctionId +
                          " current price updated.";
                }
                c.commit();
            } catch (Exception e) {
                c.rollback();
                msg = "Error removing bid: " + e.getMessage();
            }
        } // end actions

    } catch (Exception outer) {
        if (msg == null) {
            msg = "Error: " + outer.getMessage();
        }
    }
%>

<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>REP Dashboard</title>
</head>
<body>
  <h2>Customer Representative Dashboard</h2>
  <p>Logged in as <strong><%= username %></strong> (REP)</p>

  <% if (msg != null) { %>
    <p style="color:blue;"><%= msg %></p>
  <% } %>

  <hr/>

  <h3>Open Auctions (manage issues, close/cancel)</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Title</th>
      <th>Seller</th>
      <th>Current Price</th>
      <th>Ends</th>
      <th>Status</th>
      <th>Actions</th>
    </tr>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT a.auction_id, a.title, a.current_price, a.end_time, a.status, " +
           "u.username AS seller_name " +
           "FROM auctions a JOIN users u ON a.seller_id = u.user_id " +
           "WHERE a.status='OPEN' ORDER BY a.end_time ASC")) {

        try (ResultSet rs = ps.executeQuery()) {
            boolean any = false;
            while (rs.next()) {
                any = true;
%>
    <tr>
      <td><%= rs.getInt("auction_id") %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= rs.getString("seller_name") %></td>
      <td><%= rs.getBigDecimal("current_price") %></td>
      <td><%= rs.getTimestamp("end_time") %></td>
      <td><%= rs.getString("status") %></td>
      <td>
        <a href="repDashboard.jsp?action=close_auction&auction_id=<%= rs.getInt("auction_id") %>">
          Close
        </a>
        
        <a href="repDashboard.jsp?action=cancel_auction&auction_id=<%= rs.getInt("auction_id") %>">
          Cancel
        </a>
      </td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="7"><em>No open auctions.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="7">Error loading auctions: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <hr/>

  <h3>Recent Bids (remove problematic bids)</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Bid ID</th>
      <th>Auction</th>
      <th>Bidder</th>
      <th>Amount</th>
      <th>Time</th>
      <th>Action</th>
    </tr>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT b.bid_id, b.bid_amount, b.bid_time, " +
           "a.auction_id, a.title, u.username AS bidder_name " +
           "FROM bids b " +
           "JOIN auctions a ON b.auction_id = a.auction_id " +
           "JOIN users u ON b.bidder_id = u.user_id " +
           "ORDER BY b.bid_time DESC LIMIT 50")) {

        try (ResultSet rs = ps.executeQuery()) {
            boolean any = false;
            while (rs.next()) {
                any = true;
%>
    <tr>
      <td><%= rs.getInt("bid_id") %></td>
      <td>#<%= rs.getInt("auction_id") %> - <%= rs.getString("title") %></td>
      <td><%= rs.getString("bidder_name") %></td>
      <td><%= rs.getBigDecimal("bid_amount") %></td>
      <td><%= rs.getTimestamp("bid_time") %></td>
      <td>
        <a href="repDashboard.jsp?action=remove_bid&bid_id=<%= rs.getInt("bid_id") %>">
          Remove bid
        </a>
      </td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="6"><em>No bids found.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="6">Error loading bids: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p><a href="home.jsp">Back to Home</a></p>
  <p><a href="maintenance.jsp">Run maintenance (close expired auctions)</a></p>
</body>
</html>