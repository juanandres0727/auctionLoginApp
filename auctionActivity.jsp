<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    String username = (String) session.getAttribute("username");
    String role     = (String) session.getAttribute("role");

    if (username == null || role == null || !"ADMIN".equals(role)) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }

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
  <title>Auction Activity Report</title>
</head>
<body>
  <h2>Most Active Auctions (by number of bids)</h2>
  <p>Logged in as <strong><%= username %></strong> (ADMIN)</p>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Auction ID</th>
      <th>Title</th>
      <th>Seller</th>
      <th>Status</th>
      <th>Current Price</th>
      <th>Highest Bid</th>
      <th># Bids</th>
      <th>Ends</th>
    </tr>
<%
    String sql =
      "SELECT a.auction_id, a.title, a.status, a.current_price, a.end_time, " +
      "u.username AS seller_name, " +
      "COUNT(b.bid_id) AS num_bids, " +
      "MAX(b.bid_amount) AS highest_bid " +
      "FROM auctions a " +
      "JOIN users u ON a.seller_id = u.user_id " +
      "LEFT JOIN bids b ON a.auction_id = b.auction_id " +
      "GROUP BY a.auction_id, a.title, a.status, a.current_price, a.end_time, seller_name " +
      "ORDER BY num_bids DESC, a.end_time DESC " +
      "LIMIT 20";

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(sql);
         ResultSet rs = ps.executeQuery()) {

        boolean any = false;
        while (rs.next()) {
            any = true;
%>
    <tr>
      <td><%= rs.getInt("auction_id") %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= rs.getString("seller_name") %></td>
      <td><%= rs.getString("status") %></td>
      <td><%= rs.getBigDecimal("current_price") %></td>
      <td><%= rs.getBigDecimal("highest_bid") %></td>
      <td><%= rs.getInt("num_bids") %></td>
      <td><%= rs.getTimestamp("end_time") %></td>
    </tr>
<%
        }
        if (!any) {
%>
    <tr><td colspan="8"><em>No auctions / bids yet.</em></td></tr>
<%
        }
    } catch (Exception e) {
%>
    <tr><td colspan="8">Error: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p>
    <a href="adminDashboard.jsp">Back to Admin Dashboard</a> |
    <a href="home.jsp">Home</a>
  </p>
</body>
</html>