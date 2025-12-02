<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require login to browse
    Integer userIdObj = (Integer) session.getAttribute("user_id");
    String username   = (String) session.getAttribute("username");

    // Load DB props
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
  <title>All Open Auctions</title>
</head>
<body>
  <h2>All Open Auctions</h2>
<% if (username != null) { %>
  <p>Logged in as <strong><%= username %></strong></p>
<% } %>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Title</th>
      <th>Seller</th>
      <th>Current Price</th>
      <th>View</th>
    </tr>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT a.auction_id, a.title, a.current_price, " +
           "u.username AS seller_name " +
           "FROM auctions a " +
           "JOIN users u ON a.seller_id = u.user_id " +
           "WHERE a.status = 'OPEN' " +
           "ORDER BY a.auction_id DESC")) {

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
      <td>
        <a href="viewAuction.jsp?auction_id=<%= rs.getInt("auction_id") %>">View</a>
      </td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="5"><em>No open auctions found.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="5" style="color:red;">Error: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p><a href="home.jsp">Back to home</a></p>
</body>
</html>