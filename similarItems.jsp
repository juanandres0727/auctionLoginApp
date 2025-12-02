<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    request.setCharacterEncoding("UTF-8");

    String auctionStr = request.getParameter("auction_id");
    if (auctionStr == null) {
        out.println("No auction_id provided.");
        return;
    }

    int auctionId = -1;
    try {
        auctionId = Integer.parseInt(auctionStr);
    } catch (NumberFormatException e) {
        out.println("Invalid auction_id.");
        return;
    }

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

    String baseTitle = null;
    int baseCategoryId = -1;
    Timestamp baseEndTime = null;
    String baseCategoryName = null;
    String errorMsg = null;

    java.util.List<Integer> ids = new java.util.ArrayList<>();
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Similar Items (Last Month)</title>
</head>
<body>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
        //Load the base auction (to know category + end_time)
        String baseSql =
          "SELECT a.title, a.category_id, a.end_time, c.name AS category_name " +
          "FROM auctions a " +
          "JOIN categories c ON a.category_id = c.category_id " +
          "WHERE a.auction_id = ?";

        try (PreparedStatement ps = c.prepareStatement(baseSql)) {
            ps.setInt(1, auctionId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    baseTitle = rs.getString("title");
                    baseCategoryId = rs.getInt("category_id");
                    baseEndTime = rs.getTimestamp("end_time");
                    baseCategoryName = rs.getString("category_name");
                } else {
                    errorMsg = "Base auction not found.";
                }
            }
        }

        if (errorMsg != null) {
%>
  <p style="color:red;"><%= errorMsg %></p>
  <p><a href="home.jsp">Back to home</a></p>
</body>
</html>
<%
            return;
        }

        //Reference time: if base auction has end_time use that, else now.
        java.util.Date refDate = (baseEndTime != null)
            ? new java.util.Date(baseEndTime.getTime())
            : new java.util.Date();
        Timestamp refTime = new Timestamp(refDate.getTime());

        //Find similar items:
        //same category, status CLOSED, end_time in the 30 days prior to refTime, excluding this auction.
        String simSql =
          "SELECT a.auction_id, a.title, a.status, a.current_price, a.end_time, " +
          "u.username AS seller_name " +
          "FROM auctions a " +
          "JOIN users u ON a.seller_id = u.user_id " +
          "WHERE a.category_id = ? " +
          "AND a.auction_id <> ? " +
          "AND a.status = 'CLOSED' " +
          "AND a.end_time BETWEEN DATE_SUB(?, INTERVAL 30 DAY) AND ? " +
          "ORDER BY a.end_time DESC";

        try (PreparedStatement ps = c.prepareStatement(simSql)) {
            ps.setInt(1, baseCategoryId);
            ps.setInt(2, auctionId);
            ps.setTimestamp(3, refTime);
            ps.setTimestamp(4, refTime);

            try (ResultSet rs = ps.executeQuery()) {
%>
  <h2>Similar items in the last month</h2>
  <p>
    Base auction: <strong>#<%= auctionId %></strong> – "<%= baseTitle %>"<br/>
    Category: <strong><%= baseCategoryName %></strong><br/>
    Reference time: <%= refTime %><br/>
    (Showing CLOSED auctions in the same category whose end time was within 30 days before this.)
  </p>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Auction ID</th>
      <th>Title</th>
      <th>Seller</th>
      <th>Status</th>
      <th>Final Price</th>
      <th>End Time</th>
      <th>View</th>
    </tr>
<%
                boolean any = false;
                while (rs.next()) {
                    any = true;
%>
    <tr>
      <td><%= rs.getInt("auction_id") %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= rs.getString("seller_name") %></td>
      <td><%= rs.getString("status") %></td>
      <td><%= rs.getBigDecimal("current_price") %></td>
      <td><%= rs.getTimestamp("end_time") %></td>
      <td>
        <a href="viewAuction.jsp?auction_id=<%= rs.getInt("auction_id") %>">View</a>
      </td>
    </tr>
<%
                }
                if (!any) {
%>
    <tr>
      <td colspan="7">
        <em>No similar items (same category) found in the preceding month.</em>
      </td>
    </tr>
<%
                }
%>
  </table>
<%
            }
        }
    } catch (Exception e) {
%>
  <p style="color:red;">Error: <%= e.getMessage() %></p>
<%
    }
%>

  <p>
    <a href="viewAuction.jsp?auction_id=<%= auctionId %>">Back to this auction</a> |
    <a href="home.jsp">Home</a>
  </p>
</body>
</html>