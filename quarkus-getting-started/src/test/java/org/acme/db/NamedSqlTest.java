package org.acme.db;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Pruebas unitarias (sin base de datos) del convertidor de parámetros nombrados y de los .sql del proyecto. */
class NamedSqlTest {

    @Test
    void convierteParametrosNombradosAPosicionalesRespetandoElOrdenYLasRepeticiones() {
        NamedSql.Parsed p = NamedSql.parse("SELECT * FROM t WHERE a = :x AND b = :y OR c = :x");
        assertEquals("SELECT * FROM t WHERE a = ? AND b = ? OR c = ?", p.sql());
        assertEquals(List.of("x", "y", "x"), p.nombres());
    }

    @Test
    void ignoraCastsComillasYComentarios() {
        NamedSql.Parsed p = NamedSql.parse(
                "-- comentario: con dos puntos y :falso\n"
                        + "SELECT CAST(:a AS text), :b::int, 'texto :no_param', to_char(now(), 'HH24:MI') WHERE z = :c");
        assertEquals(List.of("a", "b", "c"), p.nombres());
        assertTrue(p.sql().contains("'texto :no_param'"));
        assertTrue(p.sql().contains("'HH24:MI'"));
        assertTrue(p.sql().contains("?::int"));
        assertTrue(p.sql().contains("-- comentario: con dos puntos y :falso"));
    }

    @Test
    void sinParametrosDejaLaConsultaIgual() {
        NamedSql.Parsed p = NamedSql.parse("SELECT id, nombre FROM categorias ORDER BY lower(nombre)");
        assertEquals("SELECT id, nombre FROM categorias ORDER BY lower(nombre)", p.sql());
        assertTrue(p.nombres().isEmpty());
    }

    private static String leer(String archivo) throws IOException {
        try (InputStream in = NamedSqlTest.class.getClassLoader().getResourceAsStream("sql/" + archivo + ".sql")) {
            assertNotNull(in, "Falta el recurso sql/" + archivo + ".sql");
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    /** Si una consulta cambia sus parámetros hay que actualizar también el servicio que la usa. */
    @Test
    void cadaConsultaDelProyectoExponeLosParametrosQueElServicioEnvia() throws IOException {
        Map<String, Set<String>> esperados = new LinkedHashMap<>();
        esperados.put("buscar_productos", Set.of("q", "categoria_id", "marca_id", "establecimiento_id", "ciudad",
                "precio_min", "precio_max", "orden", "limite", "desplazamiento"));
        esperados.put("comparar_precios", Set.of("producto_id", "ciudad", "establecimiento_id", "dias_vigencia"));
        esperados.put("historial_producto", Set.of("producto_id", "sede_id", "dias_vigencia", "limite"));
        esperados.put("detalle_producto", Set.of("producto_id"));
        esperados.put("foto_producto", Set.of("producto_id"));
        esperados.put("sedes", Set.of("establecimiento_id", "ciudad"));
        esperados.put("crear_usuario", Set.of("nombre", "email"));
        esperados.put("usuario_por_id", Set.of("usuario_id"));
        esperados.put("registrar_producto", Set.of("nombre", "descripcion", "marca", "categoria", "presentacion",
                "cantidad", "unidad", "foto", "foto_tipo", "usuario_id"));
        esperados.put("registrar_precio", Set.of("producto_id", "almacen", "sede", "ciudad", "direccion", "precio",
                "fecha", "usuario_id", "estado", "evidencia", "evidencia_tipo"));
        // HU-06 listas de mercado
        esperados.put("crear_lista", Set.of("usuario_id", "nombre"));
        esperados.put("renombrar_lista", Set.of("lista_id", "usuario_id", "nombre"));
        esperados.put("eliminar_lista", Set.of("lista_id", "usuario_id"));
        esperados.put("agregar_item_lista", Set.of("lista_id", "usuario_id", "producto_id", "cantidad"));
        esperados.put("modificar_item_lista", Set.of("lista_id", "usuario_id", "producto_id", "cantidad"));
        esperados.put("quitar_item_lista", Set.of("lista_id", "usuario_id", "producto_id"));
        esperados.put("listas_usuario", Set.of("usuario_id"));
        esperados.put("lista_cabecera", Set.of("lista_id", "usuario_id"));
        esperados.put("lista_items", Set.of("lista_id"));
        // HU-07 valoración de la lista
        esperados.put("lista_valoracion", Set.of("lista_id", "ciudad"));
        // HU-08 validación de precios
        esperados.put("mis_reportes", Set.of("usuario_id", "estado", "limite"));
        esperados.put("reportes_pendientes", Set.of("limite"));
        esperados.put("evidencia_reporte", Set.of("reporte_id"));
        esperados.put("validar_reporte", Set.of("reporte_id", "usuario_id"));
        esperados.put("rechazar_reporte", Set.of("reporte_id", "usuario_id", "motivo"));
        for (Map.Entry<String, Set<String>> e : esperados.entrySet()) {
            NamedSql.Parsed p = NamedSql.parse(leer(e.getKey()));
            assertEquals(new TreeSet<>(e.getValue()), new TreeSet<>(p.nombres()), "Parámetros de " + e.getKey());
        }
    }

    @Test
    void lasConsultasDeListasNoTienenParametros() throws IOException {
        for (String archivo : List.of("categorias", "marcas", "establecimientos", "ciudades")) {
            assertTrue(NamedSql.parse(leer(archivo)).nombres().isEmpty(), archivo);
        }
    }

    @Test
    void todasLasConsultasEstanCompletas() throws IOException {
        for (String archivo : List.of("buscar_productos", "comparar_precios", "historial_producto", "detalle_producto",
                "foto_producto", "categorias", "marcas", "establecimientos", "sedes", "ciudades", "crear_usuario",
                "registrar_producto", "registrar_precio")) {
            String sql = leer(archivo);
            assertFalse(sql.isBlank(), archivo);
            assertFalse(NamedSql.parse(sql).sql().contains(":nombre_sin_resolver"), archivo);
        }
    }
}
