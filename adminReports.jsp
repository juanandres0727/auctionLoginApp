<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require admin
    String role = (String) session.getAttribute("role");
    String username = (String) session.getAttribute("username");
    if (role == null || !"ADMIN".equals(role)) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }

    //Load DB
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
  <title>Admin Reports</title>
</head>
<body>

<h2>Admin Reports</h2>
<p>Logged in as: <strong><%= username %></strong> (ADMIN)</p>

<%
    // Helper: definition of "sold" for all queries below:
    // An auction counts as SOLD if:
    //   - status = 'CLOSED'
    //   - current_price >= reserve_price (or reserve_price is NULL/0)
    //
    // We'll use COALESCE(reserve_price, 0) for safety.
%>

<hr/>
<h3>Total Earnings (Sum of final prices for SOLD auctions)</h3>
<%
try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
     Statement st = c.createStatement();
     ResultSet rs = st.executeQuery(
        "SELECT COALESCE(SUM(current_price), 0) " +
        "FROM auctions " +
        "WHERE status='CLOSED' " +
        "  AND current_price >= COALESCE(reserve_price, 0)"
     )) {

    rs.next();
    double total = rs.getDouble(1);
%>
  <p><strong>$<%= total %></strong></p>
<%
} catch (Exception e) {
%>
  <p style="color:red;">Error: <%= e.getMessage() %></p>
<%
}
%>

<hr/>
<h3>Earnings Per Auction (Sold items only)</h3>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Auction ID</th>
    <th>Title</th>
    <th>Seller</th>
    <th>Final Price</th>
  </tr>
<%
try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
     PreparedStatement ps = c.prepareStatement(
       "SELECT a.auction_id, a.title, u.username AS seller_name, a.current_price " +
       "FROM auctions a " +
       "JOIN users u ON a.seller_id = u.user_id " +
       "WHERE a.status='CLOSED' " +
       "  AND a.current_price >= COALESCE(a.reserve_price, 0) " +
       "ORDER BY a.current_price DESC"
     )) {

    try (ResultSet rs = ps.executeQuery()) {
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
  <tr>
    <td><%= rs.getInt("auction_id") %></td>
    <td><%= rs.getString("title") %></td>
    <td><%= rs.getString("seller_name") %></td>
    <td>$<%= rs.getBigDecimal("current_price") %></td>
  </tr>
<%
        }
        if (!any) {
%>
  <tr><td colspan="4"><em>No sold auctions yet.</em></td></tr>
<%
        }
    }
} catch (Exception e) {
%>
  <tr><td colspan="4" style="color:red;">Error: <%= e.getMessage() %></td></tr>
<%
}
%>
</table>

<hr/>
<h3>Earnings Per Category</h3>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Category</th>
    <th>Total Earnings</th>
  </tr>
<%
try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
     PreparedStatement ps = c.prepareStatement(
       "SELECT c.name AS category_name, COALESCE(SUM(a.current_price), 0) AS total " +
       "FROM auctions a " +
       "JOIN categories c ON a.category_id = c.category_id " +
       "WHERE a.status='CLOSED' " +
       "  AND a.current_price >= COALESCE(a.reserve_price, 0) " +
       "GROUP BY c.category_id, c.name " +
       "ORDER BY total DESC"
     )) {

    try (ResultSet rs = ps.executeQuery()) {
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
  <tr>
    <td><%= rs.getString("category_name") %></td>
    <td>$<%= rs.getBigDecimal("total") %></td>
  </tr>
<%
        }
        if (!any) {
%>
  <tr><td colspan="2"><em>No earnings yet.</em></td></tr>
<%
        }
    }
} catch (Exception e) {
%>
  <tr><td colspan="2" style="color:red;">Error: <%= e.getMessage() %></td></tr>
<%
}
%>
</table>

<hr/>
<h3>Earnings Per Seller (End-user as seller)</h3>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Seller</th>
    <th>Total Earnings</th>
  </tr>
<%
try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
     PreparedStatement ps = c.prepareStatement(
       "SELECT u.username, COALESCE(SUM(a.current_price), 0) AS total " +
       "FROM auctions a " +
       "JOIN users u ON a.seller_id = u.user_id " +
       "WHERE a.status='CLOSED' " +
       "AND a.current_price >= COALESCE(a.reserve_price, 0) " +
       "GROUP BY u.user_id, u.username " +
       "ORDER BY total DESC"
     )) {

    try (ResultSet rs = ps.executeQuery()) {
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
  <tr>
    <td><%= rs.getString("username") %></td>
    <td>$<%= rs.getBigDecimal("total") %></td>
  </tr>
<%
        }
        if (!any) {
%>
  <tr><td colspan="2"><em>No seller earnings yet.</em></td></tr>
<%
        }
    }
} catch (Exception e) {
%>
  <tr><td colspan="2" style="color:red;">Error: <%= e.getMessage() %></td></tr>
<%
}
%>
</table>

<hr/>
<h3>Best-Selling Items (Top SOLD auctions by price)</h3>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Auction ID</th>
    <th>Title</th>
    <th>Final Price</th>
  </tr>
<%
try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
     PreparedStatement ps = c.prepareStatement(
       "SELECT auction_id, title, current_price " +
       "FROM auctions " +
       "WHERE status='CLOSED' " +
       "AND current_price >= COALESCE(reserve_price, 0) " +
       "ORDER BY current_price DESC " +
       "LIMIT 10"
     )) {

    try (ResultSet rs = ps.executeQuery()) {
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
  <tr>
    <td><%= rs.getInt("auction_id") %></td>
    <td><%= rs.getString("title") %></td>
    <td>$<%= rs.getBigDecimal("current_price") %></td>
  </tr>
<%
        }
        if (!any) {
%>
  <tr><td colspan="3"><em>No sold auctions yet.</em></td></tr>
<%
        }
    }
} catch (Exception e) {
%>
  <tr><td colspan="3" style="color:red;">Error: <%= e.getMessage() %></td></tr>
<%
}
%>
</table>

<hr/>
<h3>Best Buyers (Top total spent on winning bids)</h3>
<p><small>We approximate spending as the sum of winning bids on SOLD auctions.</small></p>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Buyer</th>
    <th>Total Spent</th>
  </tr>
<%
/*
  Logic for best buyers:
  - For each CLOSED, SOLD auction, find the highest bid (winner).
  - Sum those winning bid amounts per bidder.
*/

String bestBuyersSql =
  "SELECT u.username, SUM(winning_bids.win_amount) AS total_spent " +
  "FROM ( " +
  "SELECT a.auction_id, b.bidder_id, b.bid_amount AS win_amount " +
  "FROM auctions a " +
  "JOIN bids b ON a.auction_id = b.auction_id " +
  "JOIN ( " +
  "SELECT auction_id, MAX(bid_amount) AS max_bid " +
  "FROM bids GROUP BY auction_id " +
  ") mb ON b.auction_id = mb.auction_id AND b.bid_amount = mb.max_bid " +
  "WHERE a.status = 'CLOSED' " +
  "AND a.current_price >= COALESCE(a.reserve_price, 0) " +
  ") winning_bids " +
  "JOIN users u ON winning_bids.bidder_id = u.user_id " +
  "GROUP BY u.user_id, u.username " +
  "ORDER BY total_spent DESC " +
  "LIMIT 10";

try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
     PreparedStatement ps = c.prepareStatement(bestBuyersSql);
     ResultSet rs = ps.executeQuery()) {

    boolean any = false;
    while (rs.next()) {
        any = true;
%>
  <tr>
    <td><%= rs.getString("username") %></td>
    <td>$<%= rs.getBigDecimal("total_spent") %></td>
  </tr>
<%
    }
    if (!any) {
%>
  <tr><td colspan="2"><em>No buyer spending yet.</em></td></tr>
<%
    }
} catch (Exception e) {
%>
  <tr><td colspan="2" style="color:red;">Error: <%= e.getMessage() %></td></tr>
<%
}
%>
</table>

<p><a href="adminDashboard.jsp">Back to Admin Dashboard</a> | <a href="home.jsp">Home</a></p>

</body>
</html>