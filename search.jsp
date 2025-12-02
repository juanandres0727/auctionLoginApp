<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Load db properties
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");

    request.setCharacterEncoding("UTF-8");
    String q        = request.getParameter("q");
    String catStr   = request.getParameter("category_id");
    String sort     = request.getParameter("sort");

    Integer categoryId = null;
    try {
        if (catStr != null && !catStr.trim().isEmpty()) {
            categoryId = Integer.valueOf(catStr.trim());
        }
    } catch (NumberFormatException e) {
        categoryId = null;
    }

    //Sort mapping
    String orderClause;
    if ("price_asc".equals(sort)) {
        orderClause = "a.current_price ASC, a.end_time ASC";
    } else if ("price_desc".equals(sort)) {
        orderClause = "a.current_price DESC, a.end_time ASC";
    } else if ("newest".equals(sort)) {
        orderClause = "a.created_at DESC";
    } else if ("title".equals(sort)) {
        orderClause = "a.title ASC";
    } else { // default
        sort = "ending_soonest";
        orderClause = "a.end_time ASC";
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Search Auctions</title>
</head>
<body>
  <h2>Search Auctions</h2>

  <form method="get" action="search.jsp">
    <label>Keyword:
      <input type="text" name="q" size="30"
             value="<%= (q == null ? "" : q) %>">
    </label>
    &nbsp;

    <label>Category:
      <select name="category_id">
        <option value="">(any)</option>
<%
    //Load categories for dropdown
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         Statement st = c.createStatement();
         ResultSet crs = st.executeQuery("SELECT category_id, name FROM categories ORDER BY name ASC")) {

        while (crs.next()) {
            int cid = crs.getInt("category_id");
            String cname = crs.getString("name");
            String selected = (categoryId != null && categoryId == cid) ? "selected" : "";
%>
        <option value="<%= cid %>" <%= selected %>><%= cname %></option>
<%
        }
    } catch (Exception e) {
%>
        <option value="">(error loading categories)</option>
<%
    }
%>
      </select>
    </label>
    <br/><br/>

    <label>Sort by:
      <select name="sort">
        <option value="ending_soonest" <%= "ending_soonest".equals(sort) ? "selected" : "" %>>
          Ending soonest
        </option>
        <option value="price_asc" <%= "price_asc".equals(sort) ? "selected" : "" %>>
          Price (low → high)
        </option>
        <option value="price_desc" <%= "price_desc".equals(sort) ? "selected" : "" %>>
          Price (high → low)
        </option>
        <option value="newest" <%= "newest".equals(sort) ? "selected" : "" %>>
          Newly listed
        </option>
        <option value="title" <%= "title".equals(sort) ? "selected" : "" %>>
          Title (A → Z)
        </option>
      </select>
    </label>
    &nbsp;

    <button type="submit">Search</button>
  </form>

  <hr/>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Title</th>
      <th>Category</th>
      <th>Seller</th>
      <th>Current Price</th>
      <th>Ends</th>
      <th>View</th>
    </tr>
<%
    //Build query with filters
    StringBuilder sql = new StringBuilder(
      "SELECT a.auction_id, a.title, a.current_price, a.end_time, " +
      "c.name AS category_name, u.username AS seller_name " +
      "FROM auctions a " +
      "JOIN users u ON a.seller_id = u.user_id " +
      "JOIN categories c ON a.category_id = c.category_id " +
      "WHERE a.status = 'OPEN' "
    );

    java.util.List<Object> params = new java.util.ArrayList<>();

    if (q != null && !q.trim().isEmpty()) {
        sql.append(" AND (a.title LIKE ? OR a.description LIKE ?) ");
        String like = "%" + q.trim() + "%";
        params.add(like);
        params.add(like);
    }

    if (categoryId != null) {
        sql.append(" AND a.category_id = ? ");
        params.add(categoryId);
    }

    sql.append(" ORDER BY ").append(orderClause);

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
      <td><%= rs.getInt("auction_id") %></td>
      <td><%= rs.getString("title") %></td>
      <td><%= rs.getString("category_name") %></td>
      <td><%= rs.getString("seller_name") %></td>
      <td><%= rs.getBigDecimal("current_price") %></td>
      <td><%= rs.getTimestamp("end_time") %></td>
      <td><a href="viewAuction.jsp?auction_id=<%= rs.getInt("auction_id") %>">View</a></td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="7"><em>No matching auctions found.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="7">Error loading search results: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p><a href="home.jsp">Back to home</a></p>
</body>
</html>