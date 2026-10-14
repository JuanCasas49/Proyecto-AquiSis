package org.acme;

import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;

import java.time.LocalDate;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.anyOf;
import static org.hamcrest.Matchers.equalTo;

/** Utilidades compartidas por las pruebas de la API. Cada prueba usa un sufijo único para no chocar con otros datos. */
final class TestApi {

    private TestApi() {
    }

    static String sufijo() {
        return UUID.randomUUID().toString().substring(0, 8);
    }

    static long crearUsuario(String sufijo) {
        return given().contentType(ContentType.JSON)
                .body(Map.of("nombre", "Tester " + sufijo, "email", "t" + sufijo + "@example.com"))
                .when().post("/api/usuarios").then().statusCode(200)
                .extract().jsonPath().getLong("id");
    }

    static Map<String, Object> leche(String s, long usuario, String almacen, String sede, String ciudad, int precio) {
        Map<String, Object> m = new HashMap<>();
        m.put("nombre", "Leche entera " + s);
        m.put("marca", "Alquería");
        m.put("categoria", "Lácteos y huevos");
        m.put("presentacion", "Bolsa");
        m.put("cantidad", 1100);
        m.put("unidad", "ml");
        m.put("precioCop", precio);
        m.put("almacen", almacen);
        m.put("sede", sede);
        m.put("ciudad", ciudad);
        m.put("usuarioId", usuario);
        return m;
    }

    static Map<String, Object> arroz(String s, long usuario, String almacen, String sede, String ciudad, int precio) {
        Map<String, Object> m = leche(s, usuario, almacen, sede, ciudad, precio);
        m.put("nombre", "Arroz blanco " + s);
        m.put("marca", "Diana");
        m.put("categoria", "Granos y cereales");
        m.put("cantidad", 500);
        m.put("unidad", "g");
        return m;
    }

    /** Registra (o reutiliza) un producto y devuelve su id. */
    static long registrar(Map<String, Object> producto) {
        return given().contentType(ContentType.JSON).body(producto)
                .when().post("/api/productos").then().statusCode(anyOf(equalTo(200), equalTo(201)))
                .extract().jsonPath().getLong("productoId");
    }

    static void agregarPrecio(long productoId, long usuario, String almacen, String sede, String ciudad,
                              int precio, LocalDate fecha) {
        Map<String, Object> body = new HashMap<>();
        body.put("almacen", almacen);
        body.put("sede", sede);
        body.put("ciudad", ciudad);
        body.put("precioCop", precio);
        body.put("usuarioId", usuario);
        if (fecha != null) {
            body.put("fecha", fecha.toString());
        }
        given().contentType(ContentType.JSON).body(body)
                .when().post("/api/productos/" + productoId + "/precios").then().statusCode(201);
    }

    static String jpegBase64(int bytes) {
        byte[] d = new byte[bytes];
        d[0] = (byte) 0xFF;
        d[1] = (byte) 0xD8;
        d[2] = (byte) 0xFF;
        return Base64.getEncoder().encodeToString(d);
    }

    static long idPorNombre(String ruta, String nombre) {
        JsonPath jp = given().when().get(ruta).then().statusCode(200).extract().jsonPath();
        return jp.getLong("find { it.nombre == '" + nombre + "' }.id");
    }

    /**
     * Datos de prueba aislados:
     * leche  -> D1 Suba 3900 (Bogotá), Ara Kennedy 4100 (Medellín), Éxito Chapinero 5000 (Bogotá)
     * arroz  -> Jumbo Calle 80 3200 (Bogotá), D1 Suba 3600 (Bogotá)
     */
    record Fixture(String s, long usuario, long leche, long arroz) {

        static Fixture crear() {
            String s = sufijo();
            long u = crearUsuario(s);
            long leche = registrar(TestApi.leche(s, u, "D1", "D1 Suba " + s, "Bogotá", 3900));
            agregarPrecio(leche, u, "Ara", "Ara Kennedy " + s, "Medellín", 4100, null);
            agregarPrecio(leche, u, "Éxito", "Éxito Chapinero " + s, "Bogotá", 5000, null);
            long arroz = registrar(TestApi.arroz(s, u, "Jumbo", "Jumbo Calle 80 " + s, "Bogotá", 3200));
            agregarPrecio(arroz, u, "D1", "D1 Suba " + s, "Bogotá", 3600, null);
            return new Fixture(s, u, leche, arroz);
        }
    }
}
