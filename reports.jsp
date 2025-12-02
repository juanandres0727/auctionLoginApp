<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Requier admin
    String username = (String) session.getAttribute("username");
    String role     = (String) session.getAttribute("role");
    if (username == null || role == null || !"ADMIN".equals(role)) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }

    //Load db
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");
    Class.forName("com.mysql.cj.jdbc.Driver");

    Connection conn = null;
    String errorMsg = null;

    try {
        conn = DriverManager.getConnection(url, dbUser, dbPass);
    } catch (Exception e) {
        errorMsg = "Error connecting to DB: " + e.getMessage();
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Sales Reports</title>
</head>
<body>
  <h2>Sales Reports</h2>
  <p>Logged in as <strong><%= username %></strong> (ADMIN)</p>

<% if (errorMsg != null) { %>
  <p style="color:red;"><%= errorMsg %></p>
  <p><a href="home.jsp">Back to Home</a></p>
</body>
</html>
<%
    if (conn != null) conn.close();
    return;
}
%>

<hr/>

<h3>1. Total Earnings</h3>
<p><em>Assumes earnings = sum of final current_price for CLOSED auctions where reserve is met.</em></p>
<table border="1" cellpadding="4" cellspacing="0">
  <tr><th>Total Earnings</th></tr>
<%
try (PreparedStatement ps = conn.prepareStatement(
     "SELECT COALESCE(SUM(current_price),0) AS total_earnings " +
     "FROM auctions " +
     "WHERE status = 'CLOSED' " +
     "AND current_price >= reserve_price")) {

    try (ResultSet rs = ps.executeQuery()) {
        if (rs.next()) {
%>
  <tr>
    <td><%= rs.getBigDecimal("total_earnings") %></td>
  </tr>
<%
        }
    }
} catch (Exception e) {
%>
  <tr><td style="color:red;">Error: <%= e.getMessage() %></td></tr>
<%
}
%>
</table>

<hr/>

<h3>2. Earnings per Item (Auction)</h3>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Auction ID</th>
    <th>Title</th>
    <th>Status</th>
    <th>Final Price</th>
  </tr>
<%
try (PreparedStatement ps = conn.prepareStatement(
     "SELECT auction_id, title, status, current_price " +
     "FROM auctions " +
     "WHERE status = 'CLOSED' " +
     "AND current_price >= reserve_price " +
     "ORDER BY current_price DESC")) {

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
  </tr>
<%
        }
        if (!any) {
%>
  <tr><td colspan="4"><em>No closed, sold auctions yet.</em></td></tr>
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

<h3>3. Earnings per Item Type (Category)</h3>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Category</th>
    <th>Items Sold</th>
    <th>Total Earnings</th>
  </tr>
<%
try (PreparedStatement ps = conn.prepareStatement(
     "SELECT c.category_id, c.name AS category_name, " +
     "COUNT(*) AS items_sold, " +
     "SUM(a.current_price) AS total_earnings " +
     "FROM auctions a " +
     "JOIN categories c ON a.category_id = c.category_id " +
     "WHERE a.status = 'CLOSED' " +
     "AND a.current_price >= a.reserve_price " +
     "GROUP BY c.category_id, c.name " +
     "ORDER BY total_earnings DESC")) {

    try (ResultSet rs = ps.executeQuery()) {
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
  <tr>
    <td><%= rs.getString("category_name") %></td>
    <td><%= rs.getInt("items_sold") %></td>
    <td><%= rs.getBigDecimal("total_earnings") %></td>
  </tr>
<%
        }
        if (!any) {
%>
  <tr><td colspan="3"><em>No category sales yet.</em></td></tr>
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

<h3>4. Earnings per End-User (Seller)</h3>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Seller</th>
    <th>Items Sold</th>
    <th>Total Earnings</th>
  </tr>
<%
try (PreparedStatement ps = conn.prepareStatement(
     "SELECT u.user_id, u.username, " +
     "COUNT(*) AS items_sold, " +
     "SUM(a.current_price) AS total_earnings " +
     "FROM auctions a " +
     "JOIN users u ON a.seller_id = u.user_id " +
     "WHERE a.status = 'CLOSED' " +
     "AND a.current_price >= a.reserve_price " +
     "GROUP BY u.user_id, u.username " +
     "ORDER BY total_earnings DESC")) {

    try (ResultSet rs = ps.executeQuery()) {
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
  <tr>
    <td><%= rs.getString("username") %></td>
    <td><%= rs.getInt("items_sold") %></td>
    <td><%= rs.getBigDecimal("total_earnings") %></td>
  </tr>
<%
        }
        if (!any) {
%>
  <tr><td colspan="3"><em>No seller earnings yet.</em></td></tr>
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

<h3>5. Best-Selling Items (Top 10)</h3>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Auction ID</th>
    <th>Title</th>
    <th>Final Price</th>
  </tr>
<%
try (PreparedStatement ps = conn.prepareStatement(
     "SELECT auction_id, title, current_price " +
     "FROM auctions " +
     "WHERE status = 'CLOSED' " +
     "AND current_price >= reserve_price " +
     "ORDER BY current_price DESC " +
     "LIMIT 10")) {

    try (ResultSet rs = ps.executeQuery()) {
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
  <tr>
    <td><%= rs.getInt("auction_id") %></td>
    <td><%= rs.getString("title") %></td>
    <td><%= rs.getBigDecimal("current_price") %></td>
  </tr>
<%
        }
        if (!any) {
%>
  <tr><td colspan="3"><em>No best-selling items yet.</em></td></tr>
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

<h3>6. Best Buyers (Top 10)</h3>
<p><em>Winner is inferred as the bidder whose bid equals the final current_price on CLOSED auctions.</em></p>
<table border="1" cellpadding="4" cellspacing="0">
  <tr>
    <th>Buyer</th>
    <th>Items Won</th>
    <th>Total Spent</th>
  </tr>
<%
try (PreparedStatement ps = conn.prepareStatement(
     "SELECT u.user_id, u.username, " +
     "COUNT(*) AS items_won, " +
     "SUM(a.current_price) AS total_spent " +
     "FROM auctions a " +
     "JOIN bids b ON b.auction_id = a.auction_id " +
     "AND b.bid_amount = a.current_price " +
     "JOIN users u ON b.bidder_id = u.user_id " +
     "WHERE a.status = 'CLOSED' " +
     "AND a.current_price >= a.reserve_price " +
     "GROUP BY u.user_id, u.username " +
     "ORDER BY total_spent DESC " +
     "LIMIT 10")) {

    try (ResultSet rs = ps.executeQuery()) {
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
  <tr>
    <td><%= rs.getString("username") %></td>
    <td><%= rs.getInt("items_won") %></td>
    <td><%= rs.getBigDecimal("total_spent") %></td>
  </tr>
<%
        }
        if (!any) {
%>
  <tr><td colspan="3"><em>No buyer data yet.</em></td></tr>
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

<p><a href="adminDashboard.jsp">Back to Admin Dashboard</a></p>
<p><a href="home.jsp">Back to Home</a></p>

<%
    if (conn != null) {
        try { conn.close(); } catch (Exception ignore) {}
    }
%>
</body>
</html>