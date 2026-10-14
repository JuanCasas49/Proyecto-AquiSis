package org.acme.db;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.acme.ApiException;
import org.jboss.logging.Logger;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/** Acceso a Neon/PostgreSQL por JDBC (pool Agroal de Quarkus) con transacciones explícitas. */
@ApplicationScoped
public class Db {

    private static final Logger LOG = Logger.getLogger(Db.class);

    @Inject
    DataSource dataSource;

    @FunctionalInterface
    public interface Work<T> {
        T run(Connection c) throws SQLException;
    }

    @FunctionalInterface
    public interface RowMapper<T> {
        T map(ResultSet rs) throws SQLException;
    }

    /** Operación de solo lectura (autocommit). */
    public <T> T read(Work<T> work) {
        try (Connection c = dataSource.getConnection()) {
            return work.run(c);
        } catch (SQLException e) {
            throw traducir(e);
        }
    }

    /** Operación atómica: confirma si termina bien, revierte si falla. */
    public <T> T tx(Work<T> work) {
        try (Connection c = dataSource.getConnection()) {
            c.setAutoCommit(false);
            try {
                T resultado = work.run(c);
                c.commit();
                return resultado;
            } catch (SQLException | RuntimeException e) {
                try {
                    c.rollback();
                } catch (SQLException ignorada) {
                    // la conexión ya falló; se propaga el error original
                }
                throw e;
            } finally {
                try {
                    c.setAutoCommit(true);
                } catch (SQLException ignorada) {
                    // el pool descartará la conexión
                }
            }
        } catch (SQLException e) {
            throw traducir(e);
        }
    }

    public <T> List<T> list(Connection c, String sql, Params p, RowMapper<T> mapper) throws SQLException {
        try (PreparedStatement ps = NamedSql.prepare(c, sql, p); ResultSet rs = ps.executeQuery()) {
            List<T> out = new ArrayList<>();
            while (rs.next()) {
                out.add(mapper.map(rs));
            }
            return out;
        }
    }

    public <T> Optional<T> one(Connection c, String sql, Params p, RowMapper<T> mapper) throws SQLException {
        List<T> filas = list(c, sql, p, mapper);
        return filas.isEmpty() ? Optional.empty() : Optional.of(filas.get(0));
    }

    public static Integer intOrNull(ResultSet rs, String col) throws SQLException {
        int v = rs.getInt(col);
        return rs.wasNull() ? null : v;
    }

    static RuntimeException traducir(SQLException e) {
        String estado = e.getSQLState() == null ? "" : e.getSQLState();
        String mensaje = limpiar(e.getMessage());
        switch (estado) {
            case "22023":
                return new ApiException(400, mensaje);
            case "P0002":
                return new ApiException(404, mensaje);
            case "23503":
                return new ApiException(400, "Referencia inválida (por ejemplo, el usuario no existe)");
            case "23514":
            case "22001":
            case "22003":
                return new ApiException(400, "Algún dato está fuera de los límites permitidos");
            case "23505":
                return new ApiException(409, "Ya existe un registro con esos datos");
            default:
                LOG.error("Error de base de datos (SQLSTATE " + estado + ")", e);
                return new ApiException(503, "No fue posible usar la base de datos. Intente de nuevo en unos segundos.");
        }
    }

    /** "ERROR: texto\n  Where: ..." -> "texto" */
    private static String limpiar(String m) {
        if (m == null) {
            return "Solicitud inválida";
        }
        String s = m.startsWith("ERROR: ") ? m.substring(7) : m;
        int nl = s.indexOf('\n');
        return (nl >= 0 ? s.substring(0, nl) : s).trim();
    }
}
