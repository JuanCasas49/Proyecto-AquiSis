package org.acme.db;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Carga consultas desde src/main/resources/sql/{nombre}.sql y convierte los
 * parámetros nombrados (:nombre) a posicionales (?) de JDBC.
 * Ignora ::casts, literales entre comillas simples y comentarios "--".
 */
final class NamedSql {

    record Parsed(String sql, List<String> nombres) {
    }

    private static final ConcurrentHashMap<String, Parsed> CACHE = new ConcurrentHashMap<>();

    private NamedSql() {
    }

    static PreparedStatement prepare(Connection c, String archivo, Params params) throws SQLException {
        Parsed p = CACHE.computeIfAbsent(archivo, NamedSql::cargar);
        PreparedStatement ps = c.prepareStatement(p.sql());
        for (int i = 0; i < p.nombres().size(); i++) {
            Params.Valor v = params.get(p.nombres().get(i));
            int idx = i + 1;
            if (v.valor() == null) {
                ps.setNull(idx, v.tipo());
            } else if (v.tipo() == Types.BINARY) {
                ps.setBytes(idx, (byte[]) v.valor());
            } else {
                ps.setObject(idx, v.valor(), v.tipo());
            }
        }
        return ps;
    }

    private static Parsed cargar(String archivo) {
        String ruta = "sql/" + archivo + ".sql";
        try (InputStream in = NamedSql.class.getClassLoader().getResourceAsStream(ruta)) {
            if (in == null) {
                throw new IllegalStateException("No existe el recurso SQL " + ruta);
            }
            return parse(new String(in.readAllBytes(), StandardCharsets.UTF_8));
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo leer " + ruta, e);
        }
    }

    static Parsed parse(String sql) {
        StringBuilder out = new StringBuilder();
        List<String> nombres = new ArrayList<>();
        boolean comillas = false;
        int i = 0;
        while (i < sql.length()) {
            char ch = sql.charAt(i);
            char sig = i + 1 < sql.length() ? sql.charAt(i + 1) : '\0';
            if (ch == '\'') {
                comillas = !comillas;
                out.append(ch);
                i++;
            } else if (!comillas && ch == '-' && sig == '-') {
                while (i < sql.length() && sql.charAt(i) != '\n') {
                    out.append(sql.charAt(i));
                    i++;
                }
            } else if (!comillas && ch == ':' && sig == ':') {
                out.append("::");
                i += 2;
            } else if (!comillas && ch == ':' && (Character.isLetter(sig) || sig == '_')) {
                int j = i + 1;
                while (j < sql.length() && (Character.isLetterOrDigit(sql.charAt(j)) || sql.charAt(j) == '_')) {
                    j++;
                }
                nombres.add(sql.substring(i + 1, j));
                out.append('?');
                i = j;
            } else {
                out.append(ch);
                i++;
            }
        }
        return new Parsed(out.toString(), nombres);
    }
}
