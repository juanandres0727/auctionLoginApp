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

    //Load DB props
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
  <title>Auctions Matching My Alerts</title>
</head>
<body>
  <h2>Auctions matching alerts for <%= username %></h2>
  <p>
    This shows OPEN auctions that match any alert you’ve created
    (keyword, category, and/or price range).
  </p>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Auction ID</th>
      <th>Title</th>
      <th>Seller</th>
      <th>Category</th>
      <th>Current Price</th>
      <th>Ends</th>
      <th>Matches Because</th>
      <th>View</th>
    </tr>
<%
    String sql =
      "SELECT DISTINCT a.auction_id, a.title, a.current_price, a.end_time, " +
      "u.username AS seller_name, c.name AS category_name, " +
      "al.keyword, al.min_price, al.max_price " +
      "FROM alerts al " +
      "JOIN auctions a ON " +
      "(al.category_id IS NULL OR al.category_id = a.category_id) " +
      "AND (al.keyword IS NULL " +
      "OR a.title LIKE CONCAT('%', al.keyword, '%') " +
      "OR a.description LIKE CONCAT('%', al.keyword, '%')) " +
      "AND (al.min_price IS NULL OR a.current_price >= al.min_price) " +
      "AND (al.max_price IS NULL OR a.current_price <= al.max_price) " +
      "JOIN users u ON a.seller_id = u.user_id " +
      "JOIN categories c ON a.category_id = c.category_id " +
      "WHERE al.user_id = ? AND a.status = 'OPEN' " +
      "ORDER BY a.end_time ASC";

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(sql)) {

        ps.setInt(1, userId);

        try (ResultSet rs = ps.executeQuery()) {
            boolean any = false;
            while (rs.next()) {
                any = true;

                String because = "";
                String k = rs.getString("keyword");
                java.math.BigDecimal min = rs.getBigDecimal("min_price");
                java.math.BigDecimal max = rs.getBigDecimal("max_price");
                java.util.List<String> parts = new java.util.ArrayList<>();

                if (k != null)   parts.add("keyword: \"" + k + "\"");
                if (min != null) parts.add("min price ≥ " + min);
                if (max != null) parts.add("max price ≤ " + max);
                if (parts.isEmpty()) because = "Any auction (very broad alert)";
                else because = String.join(", ", parts);
%>
    <tr>
      <td><%= rs.getInt("auction_id") %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= rs.getString("seller_name") %></td>
      <td><%= rs.getString("category_name") %></td>
      <td><%= rs.getBigDecimal("current_price") %></td>
      <td><%= rs.getTimestamp("end_time") %></td>
      <td><%= because %></td>
      <td><a href="viewAuction.jsp?auction_id=<%= rs.getInt("auction_id") %>">View</a></td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="8"><em>No open auctions currently match your alerts.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="8">Error: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p>
    <a href="setAlert.jsp">Back to my alerts</a> |
    <a href="home.jsp">Back to home</a>
  </p>
</body>
</html>