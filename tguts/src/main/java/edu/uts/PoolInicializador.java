package edu.uts;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.annotation.WebListener;

/**
 * PoolInicializador - crea el pool de conexiones JDBC (HikariCP) al
 * arrancar la aplicación y lo guarda en applicationScope como "ds".
 *
 * Lee las variables de entorno DB_HOST / DB_PORT / DB_NAME / DB_USER /
 * DB_PASSWORD (igual que hacía config.jsp). En local (XAMPP) usa los
 * valores por defecto si no hay variables definidas.
 *
 * La página common/config.jsp luego hace:
 *     <sql:setDataSource var="ds" dataSource="${applicationScope.ds}"/>
 * para que JSTL reutilice las conexiones del pool (mucho más rápido que
 * abrir una conexión nueva por cada <sql:query>).
 */
@WebListener
public class PoolInicializador implements ServletContextListener {

    private static final String DRIVER = "com.mysql.cj.jdbc.Driver";
    private static final String ATTR_DS = "ds";

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        ServletContext ctx = sce.getServletContext();

        String host = env("DB_HOST", "localhost");
        String port = env("DB_PORT", "3306");
        String name = env("DB_NAME", "db_tgd_uts");
        String user = env("DB_USER", "root");
        String pass = env("DB_PASSWORD", "");

        HikariConfig cfg = new HikariConfig();
        cfg.setPoolName("tgutsPool");
        cfg.setDriverClassName(DRIVER);
        cfg.setJdbcUrl("jdbc:mysql://" + host + ":" + port + "/" + name
                + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
                + "&connectTimeout=10000&socketTimeout=30000");
        cfg.setUsername(user);
        cfg.setPassword(pass);
        cfg.setMaximumPoolSize(5);
        cfg.setMinimumIdle(0);
        cfg.setConnectionTimeout(10000);
        cfg.setIdleTimeout(300000);
        cfg.setMaxLifetime(1800000);

        ctx.setAttribute(ATTR_DS, new HikariDataSource(cfg));
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        Object ds = sce.getServletContext().getAttribute(ATTR_DS);
        if (ds instanceof HikariDataSource) {
            ((HikariDataSource) ds).close();
        }
    }

    private static String env(String key, String def) {
        String v = System.getenv(key);
        return (v == null || v.isEmpty()) ? def : v;
    }
}