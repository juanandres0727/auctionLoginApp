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

    request.setCharacterEncoding("UTF-8");

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

    String action = request.getParameter("action");
    String msg    = null;

    //Mark all as read (optional)
    if ("mark_all_read".equals(action)) {
        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
             PreparedStatement ps = c.prepareStatement(
                 "UPDATE notifications SET is_read = 1 WHERE user_id = ?"
             )) {

            ps.setInt(1, userId);    // <--- 1 placeholder, 1 setInt
            int rows = ps.executeUpdate();
            msg = "Marked " + rows + " notifications as read.";
        } catch (Exception e) {
            msg = "Error marking notifications: " + e.getMessage();
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Notifications for <%= username %></title>
</head>
<body>
  <h2>Notifications for <%= username %></h2>

<% if (msg != null) { %>
  <p style="color:blue;"><%= msg %></p>
<% } %>

  <form method="post" action="notifications.jsp">
    <input type="hidden" name="action" value="mark_all_read">
    <button type="submit">Mark all as read</button>
  </form>

  <hr/>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Message</th>
      <th>Created At</th>
      <th>Status</th>
    </tr>
<%
    //List notifications for this user
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
             "SELECT message, created_at, is_read " +
             "FROM notifications " +
             "WHERE user_id = ? " +
             "ORDER BY created_at DESC"
         )) {

        ps.setInt(1, userId);   // <--- 1 placeholder, 1 setInt

        try (ResultSet rs = ps.executeQuery()) {
            boolean any = false;
            while (rs.next()) {
                any = true;
%>
    <tr>
      <td><%= rs.getString("message") %></td>
      <td><%= rs.getTimestamp("created_at") %></td>
      <td><%= rs.getBoolean("is_read") ? "Read" : "Unread" %></td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="3"><em>No notifications.</em></td></tr>
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

  <p><a href="home.jsp">Back to home</a></p>
</body>
</html>