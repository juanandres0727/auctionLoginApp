<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require login
    Integer userIdObj = (Integer) session.getAttribute("user_id");
    if (userIdObj == null) {
        response.sendRedirect("index.jsp?msg=Please+login");
        return;
    }
    int sellerId = userIdObj;

    request.setCharacterEncoding("UTF-8");

    String title       = request.getParameter("title");
    String description = request.getParameter("description");
    String categoryStr = request.getParameter("category_id");
    String startStr    = request.getParameter("start_price");
    String minStr      = request.getParameter("min_increment");
    String reserveStr  = request.getParameter("reserve_price");
    String endStr      = request.getParameter("end_time");

    //Validation
    if (title == null || title.trim().isEmpty()
        || categoryStr == null || categoryStr.trim().isEmpty()
        || startStr == null || startStr.trim().isEmpty()
        || minStr == null || minStr.trim().isEmpty()
        || reserveStr == null || reserveStr.trim().isEmpty()
        || endStr == null || endStr.trim().isEmpty()) {

%>
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Create Auction - Error</title></head>
<body>
  <h3 style="color:red;">Missing or invalid form data.</h3>
  <p>Please go back to the auction creation form and fill in all required fields.</p>
  <p><a href="newAuction.jsp">Back to auction form</a></p>
</body>
</html>
<%
        return;
    }

    if (description == null) description = "";

    int categoryId;
    double startPrice;
    double minInc;
    double reserve;
    Timestamp endTime;

    try {
        categoryId  = Integer.parseInt(categoryStr);
        startPrice  = Double.parseDouble(startStr);
        minInc      = Double.parseDouble(minStr);
        reserve     = Double.parseDouble(reserveStr);
        endTime     = Timestamp.valueOf(endStr);  // format: YYYY-MM-DD HH:MM:SS
    } catch (NumberFormatException nfe) {
%>
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Create Auction - Error</title></head>
<body>
  <h3 style="color:red;">Invalid numeric or time input.</h3>
  <p>Make sure prices are numbers and end time is like <code>2025-12-31 23:59:00</code>.</p>
  <p><a href="newAuction.jsp">Back to auction form</a></p>
</body>
</html>
<%
        return;
    }

    //db connection
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");
    Class.forName("com.mysql.cj.jdbc.Driver");

    String msg;
    int newAuctionId = -1;

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {

        // current timestamp for start_time
        Timestamp startTime = new Timestamp(System.currentTimeMillis());

        // 1) INSERT AUCTION
        String sql =
          "INSERT INTO auctions (" +
          "    seller_id, category_id, title, description, " +
          "    start_price, current_price, min_increment, reserve_price, " +
          "    start_time, end_time, status" +
          ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'OPEN')";

        try (PreparedStatement ps = c.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, sellerId);          // seller_id
            ps.setInt(2, categoryId);        // category_id
            ps.setString(3, title);          // title
            ps.setString(4, description);    // description
            ps.setDouble(5, startPrice);     // start_price
            ps.setDouble(6, startPrice);     // current_price (init same as start)
            ps.setDouble(7, minInc);         // min_increment
            ps.setDouble(8, reserve);        // reserve_price
            ps.setTimestamp(9, startTime);   // start_time
            ps.setTimestamp(10, endTime);    // end_time

            ps.executeUpdate();

            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) newAuctionId = rs.getInt(1);
            }
        }

        // 2) MATCH ALERTS → NOTIFICATIONS
        //    Conditions:
        //      - alert.user_id != sellerId
        //      - category_id matches OR alert.category_id IS NULL
        //      - keyword is NULL OR appears in title/description
        //      - min_price is NULL OR startPrice >= min_price
        //      - max_price is NULL OR startPrice <= max_price

        String alertSql =
          "SELECT user_id, keyword " +
          "FROM alerts " +
          "WHERE user_id <> ? " +
          "AND (category_id IS NULL OR category_id = ?) " +
          "AND (keyword IS NULL " +
          "OR ? LIKE CONCAT('%', keyword, '%') " +
          "OR ? LIKE CONCAT('%', keyword, '%')) " +
          "AND (min_price IS NULL OR ? >= min_price) " +
          "AND (max_price IS NULL OR ? <= max_price)";

        try (PreparedStatement aps = c.prepareStatement(alertSql)) {
            aps.setInt(1, sellerId);         // user_id <> sellerId
            aps.setInt(2, categoryId);       // category match
            aps.setString(3, title);         // keyword in title
            aps.setString(4, description);   // keyword in description
            aps.setDouble(5, startPrice);    // min_price filter
            aps.setDouble(6, startPrice);    // max_price filter

            try (ResultSet ars = aps.executeQuery()) {
                while (ars.next()) {
                    int alertUserId = ars.getInt("user_id");

                    String notifMsg =
                      "A new auction matches your alert: \"" + title +
                      "\" (Auction #" + newAuctionId + ").";

                    try (PreparedStatement ins = c.prepareStatement(
                         "INSERT INTO notifications (user_id, message, is_read) VALUES (?, ?, 0)")) {
                        ins.setInt(1, alertUserId);
                        ins.setString(2, notifMsg);
                        ins.executeUpdate();
                    }
                }
            }
        }

        msg = "Auction created successfully. Auction ID = " + newAuctionId;
    } catch (Exception e) {
        msg = "Error creating auction: " + e.getMessage();
    }

    response.sendRedirect("home.jsp?msg=" + java.net.URLEncoder.encode(msg, "UTF-8"));
%>