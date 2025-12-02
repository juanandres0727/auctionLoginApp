<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require auction_id parameter
    String idStr = request.getParameter("auction_id");
    if (idStr == null) {
        out.println("No auction_id provided.");
        return;
    }
    int auctionId = Integer.parseInt(idStr);

    //Load db properties
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");

    //Logged-in user info
    Integer userIdObj = (Integer) session.getAttribute("user_id");
    String username   = (String) session.getAttribute("username");
    int loggedUserId  = (userIdObj == null) ? -1 : userIdObj;

    //Auction info
    String title = null, sellerName = null, categoryName = null, description = null, status = null;
    java.math.BigDecimal currentPrice = null, minIncrement = null, reservePrice = null;
    Timestamp endTime = null;
    int sellerId = -1;
    boolean canBid = false;
    String errorMsg = null;

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {

        //Load auction details 
        try (PreparedStatement ps = c.prepareStatement(
             "SELECT a.*, u.username AS seller_name, c.name AS category_name " +
             "FROM auctions a " +
             "JOIN users u ON a.seller_id = u.user_id " +
             "JOIN categories c ON a.category_id = c.category_id " +
             "WHERE a.auction_id = ?")) {

            ps.setInt(1, auctionId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    title = rs.getString("title");
                    sellerName = rs.getString("seller_name");
                    categoryName = rs.getString("category_name");
                    description = rs.getString("description");
                    status = rs.getString("status");
                    currentPrice = rs.getBigDecimal("current_price");
                    minIncrement = rs.getBigDecimal("min_increment");
                    reservePrice = rs.getBigDecimal("reserve_price");
                    endTime = rs.getTimestamp("end_time");
                    sellerId = rs.getInt("seller_id");
                } else {
                    errorMsg = "Auction not found.";
                }
            }
        }

        if (errorMsg == null) {
            java.util.Date now = new java.util.Date();
            boolean notExpired = (endTime != null && endTime.after(now));
            boolean isOpen = "OPEN".equals(status);
            boolean notSeller = (loggedUserId != -1 && loggedUserId != sellerId);
            canBid = isOpen && notExpired && notSeller;
        }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Auction Details</title>
</head>
<body>
<%
        if (errorMsg != null) {
%>
  <p><%= errorMsg %></p>
  <p><a href="home.jsp">Back to home</a></p>
<%
        } else {
%>
  <h2><%= title %></h2>
  <p><strong>Seller:</strong> <%= sellerName %></p>
  <p><strong>Category:</strong> <%= categoryName %></p>
  <p><strong>Description:</strong><br/><%= (description == null ? "" : description) %></p>
  <p><strong>Current price:</strong> <%= currentPrice %></p>
  <p><strong>Minimum increment:</strong> <%= minIncrement %></p>
  <p><strong>Reserve price:</strong> <%= reservePrice %></p>
  <p><strong>Ends at:</strong> <%= endTime %></p>
  <p><strong>Status:</strong> <%= status %></p>
  <p>
  <a href="similarItems.jsp?auction_id=<%= auctionId %>">
    View similar items in the last 30 days
  </a>
  </p>
  <p>
  <a href="askQuestion.jsp?auction_id=<%= auctionId %>">
    Ask a question about this auction
  </a>
  </p>

  <p>
  <a href="browseQuestions.jsp?auction_id=<%= auctionId %>">
    View questions & answers for this auction
  </a>
</p>

    <p>
    <strong>You are logged in as:</strong> <%= (username == null ? "Guest" : username) %>
    <br/>
    <%
      if (loggedUserId == -1) {
    %>
        (Not logged in – you cannot bid.)
    <%
      } else if (loggedUserId == sellerId) {
    %>
        (You are the <strong>SELLER</strong> for this auction – you cannot bid on your own item.)
    <%
      } else if (canBid) {
    %>
        (You are a <strong>potential BIDDER</strong> on this auction.)
    <%
      } else {
    %>
        (You are not allowed to bid on this auction – it may be closed or expired.)
    <%
      }
    %>
  </p>

<%
            //message from placeBid.jsp, if any
            String bidMsg = request.getParameter("bidMsg");
            if (bidMsg != null) {
%>
  <p style="color:red;"><%= bidMsg %></p>
<%
            }

            //bid form with auto_max field
            if (loggedUserId == -1) {
%>
  <p>You must <a href="index.jsp?msg=Please+login">log in</a> to bid.</p>
<%
            } else if (!canBid) {
%>
  <p><em>Bidding is not available (auction closed/expired or you are the seller).</em></p>
<%
            } else {
%>
  <h3>Place a bid</h3>
  <form method="post" action="placeBid.jsp">
    <input type="hidden" name="auction_id" value="<%= auctionId %>">

    <label>Bid amount:
      <input type="number" step="0.01" name="bid_amount" required>
    </label>
    <br/><br/>

    <label>Optional max auto-bid amount:
      <input type="number" step="0.01" name="auto_max">
    </label>
    <br/>
    <small>(Leave blank if you don’t want automatic bidding.)</small>
    <br/><br/>

    <button type="submit">Place bid</button>
  </form>
<%
            }

            //bid history table (simple)
%>
  <h3>Bid history</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Bidder</th>
      <th>Amount</th>
      <th>Time</th>
    </tr>
<%
            try (PreparedStatement ps = c.prepareStatement(
                 "SELECT b.bid_amount, b.bid_time, u.username " +
                 "FROM bids b JOIN users u ON b.bidder_id = u.user_id " +
                 "WHERE b.auction_id = ? ORDER BY b.bid_time DESC")) {
                ps.setInt(1, auctionId);
                try (ResultSet rs = ps.executeQuery()) {
                    boolean any = false;
                    while (rs.next()) {
                        any = true;
%>
    <tr>
      <td><%= rs.getString("username") %></td>
      <td><%= rs.getBigDecimal("bid_amount") %></td>
      <td><%= rs.getTimestamp("bid_time") %></td>
    </tr>
<%
                    }
                    if (!any) {
%>
    <tr><td colspan="3"><em>No bids yet.</em></td></tr>
<%
                    }
                }
            } catch (Exception e) {
%>
    <tr><td colspan="3">Error loading bid history: <%= e.getMessage() %></td></tr>
<%
            }
%>
  </table>

  <p><a href="myAuctions.jsp">Back to my auctions</a></p>
  <p><a href="home.jsp">Back to home</a></p>
<%
        } //end no error
    } catch (Exception e) {
%>
  <p>Error: <%= e.getMessage() %></p>
<%
    }
%>
</body>
</html>