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
  <title>Create New Auction</title>
</head>
<body>
  <h2>Create a New Auction</h2>
  <p>Logged in as <strong><%= username %></strong></p>

  <form method="post" action="createAuction.jsp">
    <p>
      <label>Title:
        <input type="text" name="title" required>
      </label>
    </p>

    <p>
      <label>Description:<br>
        <textarea name="description" rows="4" cols="50"></textarea>
      </label>
    </p>

    <p>
      <label>Category:
        <select name="category_id" required>
<%
            //populate categories from db
            try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
                 PreparedStatement ps = c.prepareStatement(
                     "SELECT category_id, name FROM categories ORDER BY name")) {

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
%>
          <option value="<%= rs.getInt("category_id") %>">
              <%= rs.getString("name") %>
          </option>
<%
                    }
                }
            } catch (Exception e) {
%>
          <option value="">(Error loading categories)</option>
<%
            }
%>
        </select>
      </label>
    </p>

    <p>
      <label>Start price:
        <input type="number" step="0.01" name="start_price" required>
      </label>
    </p>

    <p>
      <label>Minimum increment:
        <input type="number" step="0.01" name="min_increment" required>
      </label>
    </p>

    <p>
      <label>Reserve price:
        <input type="number" step="0.01" name="reserve_price" required>
      </label>
    </p>

    <p>
      <label>End time (YYYY-MM-DD HH:MM:SS):
        <input type="text" name="end_time" placeholder="2025-12-31 23:59:00" required>
      </label>
      <br>
      <small>Format must match <code>YYYY-MM-DD HH:MM:SS</code>.</small>
    </p>

    <p>
      <button type="submit">Create auction</button>
    </p>
  </form>

  <p><a href="home.jsp">Back to home</a></p>
</body>
</html>