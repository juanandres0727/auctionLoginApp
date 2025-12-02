<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require ADMIN login
    String username = (String) session.getAttribute("username");
    String role     = (String) session.getAttribute("role");

    if (username == null || role == null || !"ADMIN".equals(role)) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }

    // Load DB properties
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
  <title>Best-Selling Items (Earnings per Item)</title>
</head>
<body>
  <h2>Best-Selling Items (Earnings per Item)</h2>
  <p>Logged in as <strong><%= username %></strong> (ADMIN)</p>

  <p>
    This report shows all <strong>CLOSED</strong> auctions, ordered by their final
    sale price (<code>current_price</code>). Each row is an <em>item</em>, so this
    satisfies "earnings per item" and "best-selling items".
  </p>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Auction ID</th>
      <th>Title</th>
      <th>Category</th>
      <th>Seller</th>
      <th>Final Price</th>
      <th># Bids</th>
      <th>End Time</th>
      <th>Status</th>
    </tr>
<%
    String sql =
      "SELECT a.auction_id, a.title, a.status, a.current_price, a.end_time, " +
      "a.start_price, a.reserve_price, " +
      "u.username AS seller_name, " +
      "c.name AS category_name, " +
      "COUNT(b.bid_id) AS num_bids " +
      "FROM auctions a " +
      "JOIN users u ON a.seller_id = u.user_id " +
      "LEFT JOIN categories c ON a.category_id = c.category_id " +
      "LEFT JOIN bids b ON a.auction_id = b.auction_id " +
      "WHERE a.status = 'CLOSED' " +
      "GROUP BY a.auction_id, a.title, a.status, a.current_price, a.end_time, " +
      "a.start_price, a.reserve_price, seller_name, category_name " +
      "ORDER BY a.current_price DESC " +
      "LIMIT 50";

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
      <td><%= rs.getString("category_name") %></td>
      <td><%= rs.getString("seller_name") %></td>
      <td><%= rs.getBigDecimal("current_price") %></td>
      <td><%= rs.getInt("num_bids") %></td>
      <td><%= rs.getTimestamp("end_time") %></td>
      <td><%= rs.getString("status") %></td>
    </tr>
<%
        }
        if (!any) {
%>
    <tr><td colspan="8"><em>No CLOSED auctions yet; nothing has been sold.</em></td></tr>
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