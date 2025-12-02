<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    request.setCharacterEncoding("UTF-8");

    //Require login
    Integer userIdObj = (Integer) session.getAttribute("user_id");
    String username   = (String) session.getAttribute("username");
    if (userIdObj == null || username == null) {
        response.sendRedirect("index.jsp?msg=Please+login");
        return;
    }
    int userId = userIdObj;

    //Require auction_id
    String auctionStr = request.getParameter("auction_id");
    Integer auctionId = null;
    try {
        if (auctionStr != null) auctionId = Integer.valueOf(auctionStr);
    } catch (NumberFormatException e) {
        auctionId = null;
    }

    if (auctionId == null) {
        out.println("Missing or invalid auction_id");
        return;
    }

    // Load DB properties
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
        String text = request.getParameter("question_text");
        if (text == null || text.trim().isEmpty()) {
            msg = "Question text cannot be empty.";
        } else {
            try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
                 PreparedStatement ps = c.prepareStatement(
                   "INSERT INTO questions (auction_id, asker_id, question_text) VALUES (?,?,?)")) {
                ps.setInt(1, auctionId);
                ps.setInt(2, userId);
                ps.setString(3, text.trim());
                ps.executeUpdate();
                msg = "Your question has been submitted to customer representatives.";
            } catch (Exception e) {
                msg = "Error saving question: " + e.getMessage();
            }
        }
    }

    //Optional to show a little info about the auction:
    String auctionTitle = null;
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT title FROM auctions WHERE auction_id = ?")) {
        ps.setInt(1, auctionId);
        try (ResultSet rs = ps.executeQuery()) {
            if (rs.next()) auctionTitle = rs.getString("title");
        }
    } catch (Exception e) {
        // ignore
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Ask a Question</title>
</head>
<body>
  <h2>Ask a question about auction #<%= auctionId %></h2>
  <% if (auctionTitle != null) { %>
    <p><strong><%= auctionTitle %></strong></p>
  <% } %>

  <% if (msg != null) { %>
    <p style="color:blue;"><%= msg %></p>
  <% } %>

  <form method="post" action="askQuestion.jsp?auction_id=<%= auctionId %>">
    <p>
      <label>Your question:<br/>
        <textarea name="question_text" rows="5" cols="60"></textarea>
      </label>
    </p>
    <button type="submit">Submit question</button>
  </form>

  <p>
    <a href="viewAuction.jsp?auction_id=<%= auctionId %>">Back to auction</a> |
    <a href="home.jsp">Home</a>
  </p>
</body>
</html>