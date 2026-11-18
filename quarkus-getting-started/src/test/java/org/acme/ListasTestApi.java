package org.acme;

import io.restassured.http.ContentType;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

import static io.restassured.RestAssured.given;

/** Utilidades de las pruebas de listas de mercado, valoración y validación de precios. */
final class ListasTestApi {

    private ListasTestApi() {
    }

    static long crearLista(long usuario, String nombre) {
        return given().contentType(ContentType.JSON).body(Map.of("usuarioId", usuario, "nombre", nombre))
                .when().post("/api/listas").then().statusCode(201).extract().jsonPath().getLong("id");
    }

    static void agregar(long lista, long usuario, long producto, int cantidad) {
        given().contentType(ContentType.JSON)
                .body(Map.of("usuarioId", usuario, "productoId", producto, "cantidad", cantidad))
                .when().post("/api/listas/" + lista + "/items").then().statusCode(201);
    }

    /** Registra un producto con su primer precio y devuelve su id. */
    static long producto(String nombre, String marca, String categoria, long usuario, String almacen, String sede,
                         String ciudad, int precio) {
        Map<String, Object> m = new HashMap<>();
        m.put("nombre", nombre);
        m.put("marca", marca);
        m.put("categoria", categoria);
        m.put("presentacion", "Bolsa");
        m.put("cantidad", 500);
        m.put("unidad", "g");
        m.put("precioCop", precio);
        m.put("almacen", almacen);
        m.put("sede", sede);
        m.put("ciudad", ciudad);
        m.put("usuarioId", usuario);
        return TestApi.registrar(m);
    }

    static void precio(long producto, long usuario, String almacen, String sede, String ciudad, int precio, LocalDate fecha) {
        TestApi.agregarPrecio(producto, usuario, almacen, sede, ciudad, precio, fecha);
    }

    /**
     * Escenario de HU-07 (almacenes con sufijo para aislarlo de otros datos):
     * leche x2, arroz x1, aceite x1.  Éxito 5000/3600/12000 = 25.600 · Ara 4100/3500/11000 = 22.700 (aceite de 45 días)
     * · D1 3900/3200 y sin aceite = 11.000 parcial.
     */
    record Escenario(String s, long usuario, long leche, long arroz, long aceite, long lista,
                     String exito, String d1, String ara) {

        static Escenario crear() {
            String s = TestApi.sufijo();
            long u = TestApi.crearUsuario(s);
            String exito = "Éxito " + s;
            String d1 = "D1 " + s;
            String ara = "Ara " + s;
            long leche = producto("Leche V " + s, "Alquería", "Lácteos y huevos", u, exito, exito + " Norte", "Bogotá", 5000);
            long arroz = producto("Arroz V " + s, "Diana", "Granos y cereales", u, exito, exito + " Norte", "Bogotá", 3600);
            long aceite = producto("Aceite V " + s, "Gourmet", "Despensa", u, exito, exito + " Norte", "Bogotá", 12000);
            precio(leche, u, d1, d1 + " Sur", "Bogotá", 3900, null);
            precio(arroz, u, d1, d1 + " Sur", "Bogotá", 3200, null);
            precio(leche, u, ara, ara + " Centro", "Bogotá", 4100, null);
            precio(arroz, u, ara, ara + " Centro", "Bogotá", 3500, null);
            precio(aceite, u, ara, ara + " Centro", "Bogotá", 11000, LocalDate.now().minusDays(45));
            long lista = crearLista(u, "Mercado " + s);
            agregar(lista, u, leche, 2);
            agregar(lista, u, arroz, 1);
            agregar(lista, u, aceite, 1);
            return new Escenario(s, u, leche, arroz, aceite, lista, exito, d1, ara);
        }
    }
}
