<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Login Result</title></head>
<body><pre>
<%
request.setCharacterEncoding("UTF-8");
String username = request.getParameter("username");
String password = request.getParameter("password");

boolean ok = false;
String message = "Invalid username or password.";
int userId = -1;
String role = null;

if (username != null && password != null) {
  try {
    // Load DB properties
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
      props.load(fis);
    }

    String url  = props.getProperty("db.url");
    String user = props.getProperty("db.user");
    String pass = props.getProperty("db.password");

    // Load MySQL driver (ensure mysql-connector-j-*.jar is in WEB-INF/lib)
    Class.forName("com.mysql.cj.jdbc.Driver");

    // Check username + password hash + active flag
    try (Connection c = DriverManager.getConnection(url, user, pass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT user_id, role " +
           "FROM users " +
           "WHERE username=? AND password_hash = SHA2(?,256) AND active=1")) {

      ps.setString(1, username);
      ps.setString(2, password);

      try (ResultSet rs = ps.executeQuery()) {
        if (rs.next()) {
          ok = true;
          userId = rs.getInt("user_id");
          role   = rs.getString("role");   // END_USER / REP / ADMIN
        }
      }
    }
  } catch (Exception e) {
    message = "DB error: " + e.getMessage();
  }
}

if (ok) {
  // Store everything we need for the rest of the site
  session.setAttribute("user_id", userId);
  session.setAttribute("username", username);
  session.setAttribute("role", role);

  // Either redirect silently...
  response.sendRedirect("home.jsp");
  return;
} else {
  out.println("❌ " + message);
  out.println("<br><a href='index.jsp'>Back</a>");
}
%>
</pre></body>
</html>