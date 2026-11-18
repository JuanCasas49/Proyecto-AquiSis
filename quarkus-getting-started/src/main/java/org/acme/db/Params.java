package org.acme.db;

import java.math.BigDecimal;
import java.sql.Types;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

/** Parámetros nombrados con tipo SQL explícito (así los NULL siempre tienen tipo). */
public final class Params {

    record Valor(Object valor, int tipo) {
    }

    private final Map<String, Valor> valores = new HashMap<>();

    public static Params of() {
        return new Params();
    }

    private Params put(String nombre, Object valor, int tipo) {
        valores.put(nombre, new Valor(valor, tipo));
        return this;
    }

    public Params text(String n, String v) {
        return put(n, v, Types.VARCHAR);
    }

    public Params bigint(String n, Long v) {
        return put(n, v, Types.BIGINT);
    }

    public Params integer(String n, Integer v) {
        return put(n, v, Types.INTEGER);
    }

    public Params num(String n, BigDecimal v) {
        return put(n, v, Types.NUMERIC);
    }

    public Params date(String n, LocalDate v) {
        return put(n, v, Types.DATE);
    }

    public Params bytes(String n, byte[] v) {
        return put(n, v, Types.BINARY);
    }

    Valor get(String nombre) {
        Valor v = valores.get(nombre);
        if (v == null) {
            throw new IllegalArgumentException("Falta el parámetro SQL :" + nombre);
        }
        return v;
    }
}
