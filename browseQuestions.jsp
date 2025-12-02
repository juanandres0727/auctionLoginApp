<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    request.setCharacterEncoding("UTF-8");

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

    String keyword    = request.getParameter("q");
    String auctionStr = request.getParameter("auction_id");
    Integer auctionId = null;
    try {
        if (auctionStr != null && !auctionStr.trim().isEmpty()) {
            auctionId = Integer.valueOf(auctionStr.trim());
        }
    } catch (NumberFormatException e) {
        auctionId = null;
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Browse Questions & Answers</title>
</head>
<body>
  <h2>Browse Questions & Answers</h2>

  <p>
    Here you can see questions asked about auctions and the answers
    given by customer representatives. Use the search form to filter by
    keywords or a specific auction.
  </p>

  <!-- Search form -->
  <form method="get" action="browseQuestions.jsp">
    <label>Keyword:
      <input type="text" name="q"
             value="<%= (keyword == null ? "" : keyword) %>">
    </label>
    &nbsp;
    <label>Auction ID (optional):
      <input type="text" name="auction_id"
             value="<%= (auctionId == null ? "" : auctionId) %>">
    </label>
    &nbsp;
    <button type="submit">Search</button>
  </form>

  <hr/>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Auction</th>
      <th>Asker</th>
      <th>Asked At</th>
      <th>Question</th>
      <th>Answer</th>
      <th>Answered By</th>
      <th>Answered At</th>
    </tr>
<%
    StringBuilder sql = new StringBuilder(
      "SELECT q.question_id, q.auction_id, q.question_text, q.answer_text, " +
      "q.asked_at, q.answered_at, " +
      "a.title AS auction_title, " +
      "asker.username AS asker_name, " +
      "rep.username   AS rep_name " +
      "FROM questions q " +
      "JOIN auctions a ON q.auction_id = a.auction_id " +
      "JOIN users asker ON q.asker_id = asker.user_id " +
      "LEFT JOIN users rep ON q.answered_by = rep.user_id " +
      "WHERE q.answer_text IS NOT NULL "
    );

    java.util.List<Object> params = new java.util.ArrayList<>();

    if (auctionId != null) {
        sql.append(" AND q.auction_id = ? ");
        params.add(auctionId);
    }

    if (keyword != null && !keyword.trim().isEmpty()) {
        sql.append(" AND (q.question_text LIKE ? OR q.answer_text LIKE ? OR a.title LIKE ?) ");
        String like = "%" + keyword.trim() + "%";
        params.add(like);
        params.add(like);
        params.add(like);
    }

    sql.append(" ORDER BY q.answered_at DESC, q.asked_at DESC LIMIT 100 ");

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(sql.toString())) {

        int idx = 1;
        for (Object p : params) {
            if (p instanceof Integer) ps.setInt(idx++, (Integer)p);
            else                      ps.setString(idx++, (String)p);
        }

        try (ResultSet rs = ps.executeQuery()) {
            boolean any = false;
            while (rs.next()) {
                any = true;
%>
    <tr>
      <td><%= rs.getInt("question_id") %></td>
      <td>
        #<%= rs.getInt("auction_id") %> - 
        <a href="viewAuction.jsp?auction_id=<%= rs.getInt("auction_id") %>">
          <%= rs.getString("auction_title") %>
        </a>
      </td>
      <td><%= rs.getString("asker_name") %></td>
      <td><%= rs.getTimestamp("asked_at") %></td>
      <td><%= rs.getString("question_text") %></td>
      <td><%= rs.getString("answer_text") %></td>
      <td><%= (rs.getString("rep_name") == null ? "(unknown)" : rs.getString("rep_name")) %></td>
      <td><%= rs.getTimestamp("answered_at") %></td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="8"><em>No answered questions match your search.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="8">Error loading questions: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p>
    <a href="home.jsp">Home</a>
  </p>
</body>
</html>