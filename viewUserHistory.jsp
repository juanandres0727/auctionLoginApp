<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require login
    Integer currentIdObj = (Integer) session.getAttribute("user_id");
    String currentUser   = (String) session.getAttribute("username");
    if (currentIdObj == null || currentUser == null) {
        response.sendRedirect("index.jsp?msg=Please+login");
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

    request.setCharacterEncoding("UTF-8");
    String usernameParam = request.getParameter("username");

    Integer targetUserId   = null;
    String  targetUsername = null;
    String  errorMsg       = null;

    if (usernameParam != null && !usernameParam.trim().isEmpty()) {
        // Look up user by exact username
        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
             PreparedStatement ps = c.prepareStatement(
               "SELECT user_id, username FROM users WHERE username = ?")) {
            ps.setString(1, usernameParam.trim());
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    targetUserId   = rs.getInt("user_id");
                    targetUsername = rs.getString("username");
                } else {
                    errorMsg = "No user found with username '" + usernameParam.trim() + "'.";
                }
            }
        } catch (Exception e) {
            errorMsg = "Error looking up user: " + e.getMessage();
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>View User History</title>
</head>
<body>
  <h2>View User History (Buyer & Seller)</h2>
  <p>Logged in as <strong><%= currentUser %></strong></p>

  <!-- Search form -->
  <form method="get" action="viewUserHistory.jsp">
    <label>Username:
      <input type="text" name="username"
             value="<%= (usernameParam == null ? "" : usernameParam) %>">
    </label>
    <button type="submit">Lookup</button>
  </form>

  <hr/>

<%
    if (usernameParam == null || usernameParam.trim().isEmpty()) {
%>
  <p><em>Enter a username above to see that user's auctions and bidding history.</em></p>
<%
    } else if (errorMsg != null) {
%>
  <p style="color:red;"><%= errorMsg %></p>
<%
    } else {
%>
  <h3>History for user: <strong><%= targetUsername %></strong> (ID <%= targetUserId %>)</h3>

  <!-- 1. Auctions this user has SOLD / is selling -->
  <h4>Auctions where this user is the SELLER</h4>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Auction ID</th>
      <th>Title</th>
      <th>Status</th>
      <th>Final / Current Price</th>
      <th>End Time</th>
      <th>View</th>
    </tr>
<%
        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
             PreparedStatement ps = c.prepareStatement(
               "SELECT auction_id, title, status, current_price, end_time " +
               "FROM auctions " +
               "WHERE seller_id = ? " +
               "ORDER BY end_time DESC")) {

            ps.setInt(1, targetUserId);
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
    <tr><td colspan="6"><em>This user has not created any auctions.</em></td></tr>
<%
                }
            }
        } catch (Exception e) {
%>
    <tr><td colspan="6">Error loading seller history: <%= e.getMessage() %></td></tr>
<%
        }
%>
  </table>

  <br/>

  <!-- 2. Auctions this user has BID on -->
  <h4>Auctions where this user has placed BIDS</h4>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Auction ID</th>
      <th>Title</th>
      <th>Status</th>
      <th>User's Max Bid</th>
      <th>Current / Final Price</th>
      <th>End Time</th>
      <th>View</th>
    </tr>
<%
        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
             PreparedStatement ps = c.prepareStatement(
               "SELECT a.auction_id, a.title, a.status, a.current_price, a.end_time, " +
               "MAX(b.bid_amount) AS user_max_bid " +
               "FROM bids b " +
               "JOIN auctions a ON b.auction_id = a.auction_id " +
               "WHERE b.bidder_id = ? " +
               "GROUP BY a.auction_id, a.title, a.status, a.current_price, a.end_time " +
               "ORDER BY a.end_time DESC")) {

            ps.setInt(1, targetUserId);
            try (ResultSet rs = ps.executeQuery()) {
                boolean any = false;
                while (rs.next()) {
                    any = true;
%>
    <tr>
      <td><%= rs.getInt("auction_id") %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= rs.getString("status") %></td>
      <td><%= rs.getBigDecimal("user_max_bid") %></td>
      <td><%= rs.getBigDecimal("current_price") %></td>
      <td><%= rs.getTimestamp("end_time") %></td>
      <td><a href="viewAuction.jsp?auction_id=<%= rs.getInt("auction_id") %>">View</a></td>
    </tr>
<%
                }
                if (!any) {
%>
    <tr><td colspan="7"><em>This user has not bid on any auctions.</em></td></tr>
<%
                }
            }
        } catch (Exception e) {
%>
    <tr><td colspan="7">Error loading bidding history: <%= e.getMessage() %></td></tr>
<%
        }
%>
  </table>
<%
    } // end "user found" branch
%>

  <p><a href="home.jsp">Back to home</a></p>
</body>
</html>