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
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>My Auctions</title>
</head>
<body>
  <h2>My Auctions</h2>
  <p>Logged in as <strong><%= username %></strong></p>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Title</th>
      <th>Status</th>
      <th>Current Price</th>
      <th>Ends At</th>
      <th>View</th>
    </tr>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT auction_id, title, status, current_price, end_time " +
           "FROM auctions " +
           "WHERE seller_id = ? " +
           "ORDER BY auction_id DESC")) {

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
      <td>
        <a href="viewAuction.jsp?auction_id=<%= rs.getInt("auction_id") %>">View</a>
      </td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="6"><em>You have not created any auctions yet.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="6" style="color:red;">Error: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p><a href="home.jsp">Back to home</a></p>
</body>
</html>