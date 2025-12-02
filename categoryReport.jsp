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
  <title>Category Performance Report</title>
</head>
<body>
  <h2>Category Performance</h2>
  <p>Logged in as <strong><%= username %></strong> (ADMIN)</p>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Category</th>
      <th>Total Auctions</th>
      <th>Closed Auctions</th>
      <th>Total Closed Revenue</th>
      <th>Average Closing Price</th>
    </tr>
<%
    String sql =
      "SELECT c.category_id, c.name, " +
      "COUNT(a.auction_id) AS total_auctions, " +
      "SUM(CASE WHEN a.status='CLOSED' THEN 1 ELSE 0 END) AS closed_auctions, " +
      "COALESCE(SUM(CASE WHEN a.status='CLOSED' THEN a.current_price ELSE 0 END), 0) AS total_closed_revenue, " +
      "COALESCE(AVG(CASE WHEN a.status='CLOSED' THEN a.current_price END), 0) AS avg_closing_price " +
      "FROM categories c " +
      "LEFT JOIN auctions a ON a.category_id = c.category_id " +
      "GROUP BY c.category_id, c.name " +
      "ORDER BY total_closed_revenue DESC, total_auctions DESC";

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(sql);
         ResultSet rs = ps.executeQuery()) {

        boolean any = false;
        while (rs.next()) {
            any = true;
%>
    <tr>
      <td><%= rs.getString("name") %></td>
      <td><%= rs.getInt("total_auctions") %></td>
      <td><%= rs.getInt("closed_auctions") %></td>
      <td><%= rs.getBigDecimal("total_closed_revenue") %></td>
      <td><%= rs.getBigDecimal("avg_closing_price") %></td>
    </tr>
<%
        }
        if (!any) {
%>
    <tr><td colspan="5"><em>No categories or auctions yet.</em></td></tr>
<%
        }
    } catch (Exception e) {
%>
    <tr><td colspan="5">Error: <%= e.getMessage() %></td></tr>
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