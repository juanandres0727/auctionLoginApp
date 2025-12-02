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
  <title>Top Sellers Report</title>
</head>
<body>
  <h2>Top Sellers (by revenue from CLOSED auctions)</h2>
  <p>Logged in as <strong><%= username %></strong> (ADMIN)</p>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Rank</th>
      <th>Seller</th>
      <th>Closed Auctions</th>
      <th>Total Revenue</th>
    </tr>
<%
    String sql =
      "SELECT u.user_id, u.username, " +
      "COUNT(a.auction_id) AS num_closed, " +
      "COALESCE(SUM(a.current_price), 0) AS total_revenue " +
      "FROM auctions a " +
      "JOIN users u ON a.seller_id = u.user_id " +
      "WHERE a.status = 'CLOSED' " +
      "GROUP BY u.user_id, u.username " +
      "ORDER BY total_revenue DESC " +
      "LIMIT 20";

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(sql);
         ResultSet rs = ps.executeQuery()) {

        int rank = 1;
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
    <tr>
      <td><%= rank++ %></td>
      <td><%= rs.getString("username") %></td>
      <td><%= rs.getInt("num_closed") %></td>
      <td><%= rs.getBigDecimal("total_revenue") %></td>
    </tr>
<%
        }
        if (!any) {
%>
    <tr><td colspan="4"><em>No CLOSED auctions yet, so no seller revenue.</em></td></tr>
<%
        }
    } catch (Exception e) {
%>
    <tr><td colspan="4">Error: <%= e.getMessage() %></td></tr>
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