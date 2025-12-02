<%@ page contentType="text/html; charset=UTF-8" %>
<%
    if (session != null) {
        session.invalidate();
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Logged Out</title>
</head>
<body>
  <h3>You have been logged out.</h3>
  <a href="index.jsp">Return to login</a>
</body>
</html>