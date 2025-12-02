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

    //Load DB properties
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");

    String method = request.getMethod();
    String msg = null;

    if ("POST".equalsIgnoreCase(method)) {
        request.setCharacterEncoding("UTF-8");
        String catStr   = request.getParameter("category_id");
        String keyword  = request.getParameter("keyword");
        String minStr   = request.getParameter("min_price");
        String maxStr   = request.getParameter("max_price");

        Integer categoryId = null;
        Double minPrice = null, maxPrice = null;

        try {
            if (catStr != null && !catStr.isEmpty()) categoryId = Integer.valueOf(catStr);
            if (minStr != null && !minStr.isEmpty()) minPrice   = Double.valueOf(minStr);
            if (maxStr != null && !maxStr.isEmpty()) maxPrice   = Double.valueOf(maxStr);
        } catch (NumberFormatException e) {
            msg = "Invalid number in min or max price.";
        }

        if (msg == null && (keyword == null || keyword.trim().isEmpty())
            && categoryId == null && minPrice == null && maxPrice == null) {
            msg = "Please specify at least one condition (keyword, category, or price range).";
        }

        if (msg == null) {
            try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
                 PreparedStatement ps = c.prepareStatement(
                   "INSERT INTO alerts (user_id, category_id, keyword, min_price, max_price) " +
                   "VALUES (?,?,?,?,?)")) {

                ps.setInt(1, userId);
                if (categoryId == null) ps.setNull(2, Types.INTEGER); else ps.setInt(2, categoryId);
                if (keyword == null || keyword.trim().isEmpty()) ps.setNull(3, Types.VARCHAR);
                else ps.setString(3, keyword.trim());
                if (minPrice == null) ps.setNull(4, Types.DECIMAL); else ps.setDouble(4, minPrice);
                if (maxPrice == null) ps.setNull(5, Types.DECIMAL); else ps.setDouble(5, maxPrice);

                ps.executeUpdate();
                msg = "Alert created.";
            } catch (Exception e) {
                msg = "Error creating alert: " + e.getMessage();
            }
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>My Alerts</title>
</head>
<body>
  <h2>Alerts for <%= username %></h2>

  <% if (msg != null) { %>
    <p style="color:blue;"><%= msg %></p>
  <% } %>

  <h3>Create new alert</h3>
  <form method="post" action="setAlert.jsp">
    <label>Keyword:
      <input type="text" name="keyword">
    </label>
    <br/><br/>

    <label>Category:
      <select name="category_id">
        <option value="">-- Any --</option>
        <%
          try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
               PreparedStatement ps = c.prepareStatement(
                 "SELECT category_id, name FROM categories ORDER BY name")) {
            try (ResultSet rs = ps.executeQuery()) {
              while (rs.next()) {
        %>
          <option value="<%= rs.getInt("category_id") %>"><%= rs.getString("name") %></option>
        <%
              }
            }
          } catch (Exception e) {
        %>
          <option disabled>Error loading categories</option>
        <%
          }
        %>
      </select>
    </label>
    <br/><br/>

    <label>Min price:
      <input type="number" step="0.01" name="min_price">
    </label>
    <br/><br/>

    <label>Max price:
      <input type="number" step="0.01" name="max_price">
    </label>
    <br/><br/>

    <button type="submit">Save alert</button>
  </form>

  <hr/>

  <h3>My existing alerts</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Keyword</th>
      <th>Category</th>
      <th>Min price</th>
      <th>Max price</th>
      <th>Created</th>
    </tr>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT a.alert_id, a.keyword, a.min_price, a.max_price, a.created_at, " +
           "c.name AS category_name " +
           "FROM alerts a LEFT JOIN categories c ON a.category_id = c.category_id " +
           "WHERE a.user_id = ? ORDER BY a.created_at DESC")) {

        ps.setInt(1, userId);
        try (ResultSet rs = ps.executeQuery()) {
            boolean any = false;
            while (rs.next()) {
                any = true;
%>
    <tr>
      <td><%= rs.getInt("alert_id") %></td>
      <td><%= rs.getString("keyword") %></td>
      <td><%= rs.getString("category_name") %></td>
      <td><%= rs.getBigDecimal("min_price") %></td>
      <td><%= rs.getBigDecimal("max_price") %></td>
      <td><%= rs.getTimestamp("created_at") %></td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="6"><em>You have no alerts yet.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="6">Error loading alerts: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p>
    <a href="alertMatches.jsp">View auctions matching my alerts</a> |
    <a href="home.jsp">Back to home</a>
  </p>
</body>
</html>