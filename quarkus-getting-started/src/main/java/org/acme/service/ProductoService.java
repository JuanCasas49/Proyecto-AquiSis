package org.acme.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.acme.ApiException;
import org.acme.db.Db;
import org.acme.db.Params;
import org.acme.dto.Dtos.Comparacion;
import org.acme.dto.Dtos.Foto;
import org.acme.dto.Dtos.NuevoPrecioRequest;
import org.acme.dto.Dtos.PaginaProductos;
import org.acme.dto.Dtos.PrecioSede;
import org.acme.dto.Dtos.ProductoDetalle;
import org.acme.dto.Dtos.ProductoResumen;
import org.acme.dto.Dtos.RegistroProductoRequest;
import org.acme.dto.Dtos.RegistroResponse;
import org.acme.dto.Dtos.Reporte;
import org.acme.dto.Dtos.ResumenComparacion;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@ApplicationScoped
public class ProductoService {

    private static final Set<String> UNIDADES = Set.of("g", "kg", "ml", "l", "un");
    private static final Set<String> ORDENES = Set.of("nombre", "precio_asc", "precio_desc", "reciente");
    private static final int MAX_FOTO_BYTES = 1_048_576;

    @Inject
    Db db;

    @ConfigProperty(name = "app.precios.dias-vigencia", defaultValue = "30")
    int diasVigencia;

    private record ProductoCreado(long id, boolean nuevo) {
    }

    // ------------------------------------------------------------ registro --

    public RegistroResponse registrar(RegistroProductoRequest r) {
        String unidad = r.unidad().trim().toLowerCase(Locale.ROOT);
        if (!UNIDADES.contains(unidad)) {
            throw new ApiException(400, "La unidad debe ser una de: g, kg, ml, l, un");
        }
        Foto foto = decodificarFoto(r.fotoBase64());
        return db.tx(c -> {
            ProductoCreado pc = db.one(c, "registrar_producto", Params.of()
                    .text("nombre", r.nombre()).text("descripcion", r.descripcion())
                    .text("marca", r.marca()).text("categoria", r.categoria())
                    .text("presentacion", r.presentacion()).num("cantidad", r.cantidad())
                    .text("unidad", unidad)
                    .bytes("foto", foto == null ? null : foto.datos())
                    .text("foto_tipo", foto == null ? null : foto.tipo())
                    .bigint("usuario_id", r.usuarioId()),
                    rs -> new ProductoCreado(rs.getLong("producto_id"), rs.getBoolean("nuevo"))).orElseThrow();
            long reporte = insertarPrecio(c, pc.id(), r.almacen(), r.sede(), r.ciudad(), r.direccion(),
                    r.precioCop(), r.fecha(), r.usuarioId());
            return new RegistroResponse(pc.id(), reporte, pc.nuevo());
        });
    }

    public RegistroResponse agregarPrecio(long productoId, NuevoPrecioRequest r) {
        return db.tx(c -> {
            long reporte = insertarPrecio(c, productoId, r.almacen(), r.sede(), r.ciudad(), r.direccion(),
                    r.precioCop(), r.fecha(), r.usuarioId());
            return new RegistroResponse(productoId, reporte, false);
        });
    }

    private long insertarPrecio(Connection c, long productoId, String almacen, String sede, String ciudad,
                                String direccion, BigDecimal precio, LocalDate fecha, Long usuarioId) throws SQLException {
        return db.one(c, "registrar_precio", Params.of()
                .bigint("producto_id", productoId).text("almacen", almacen).text("sede", sede)
                .text("ciudad", ciudad).text("direccion", direccion).num("precio", precio)
                .date("fecha", fecha).bigint("usuario_id", usuarioId),
                rs -> rs.getLong("reporte_id")).orElseThrow();
    }

    // ------------------------------------------------------------ catálogo --

    public PaginaProductos buscar(String q, Long categoriaId, Long marcaId, Long establecimientoId, String ciudad,
                                  BigDecimal precioMin, BigDecimal precioMax, String orden, int pagina, int tamano) {
        if (precioMin != null && precioMax != null && precioMin.compareTo(precioMax) > 0) {
            throw new ApiException(400, "El precio mínimo no puede ser mayor que el máximo");
        }
        if (tamano < 1 || tamano > 100) {
            throw new ApiException(400, "El tamaño de página debe estar entre 1 y 100");
        }
        if (pagina < 1) {
            throw new ApiException(400, "La página debe ser 1 o mayor");
        }
        String ord = orden == null || orden.isBlank() ? "nombre" : orden.trim();
        if (!ORDENES.contains(ord)) {
            throw new ApiException(400, "Orden inválido. Use: nombre, precio_asc, precio_desc o reciente");
        }
        String texto = blanco(q);
        if (texto != null && texto.length() > 100) {
            throw new ApiException(400, "La búsqueda admite máximo 100 caracteres");
        }
        Params p = Params.of().text("q", texto).bigint("categoria_id", categoriaId).bigint("marca_id", marcaId)
                .bigint("establecimiento_id", establecimientoId).text("ciudad", blanco(ciudad))
                .num("precio_min", precioMin).num("precio_max", precioMax).text("orden", ord)
                .integer("limite", tamano).integer("desplazamiento", (pagina - 1) * tamano);
        long[] total = {0};
        List<ProductoResumen> items = db.read(c -> db.list(c, "buscar_productos", p, rs -> {
            total[0] = rs.getLong("total");
            Integer dias = Db.intOrNull(rs, "dias_ultima");
            LocalDate ultima = rs.getObject("ultima_fecha", LocalDate.class);
            return new ProductoResumen(rs.getLong("id"), rs.getString("nombre"), rs.getString("marca"),
                    rs.getString("categoria"), rs.getString("presentacion"), rs.getBigDecimal("cantidad"),
                    rs.getString("unidad"), rs.getBoolean("tiene_foto"), rs.getBigDecimal("precio_min"),
                    rs.getBigDecimal("precio_max"), rs.getInt("n_sedes"), ultima == null ? null : ultima.toString(),
                    dias, dias != null && dias > diasVigencia, rs.getString("mejor_almacen"),
                    rs.getString("mejor_sede"), rs.getString("mejor_ciudad"));
        }));
        return new PaginaProductos(items, total[0], pagina, tamano);
    }

    public ProductoDetalle detalle(long id) {
        return db.read(c -> db.one(c, "detalle_producto", Params.of().bigint("producto_id", id),
                rs -> new ProductoDetalle(rs.getLong("id"), rs.getString("nombre"), rs.getString("descripcion"),
                        rs.getString("marca"), rs.getString("categoria"), rs.getLong("marca_id"),
                        rs.getLong("categoria_id"), rs.getString("presentacion"), rs.getBigDecimal("cantidad"),
                        rs.getString("unidad"), rs.getBoolean("tiene_foto"), rs.getString("creado_por"),
                        rs.getString("creado_en")))
                .orElseThrow(() -> new ApiException(404, "Producto no encontrado")));
    }

    public Foto foto(long id) {
        return db.read(c -> db.one(c, "foto_producto", Params.of().bigint("producto_id", id),
                rs -> new Foto(rs.getBytes("foto"), rs.getString("foto_tipo")))
                .orElseThrow(() -> new ApiException(404, "El producto no tiene fotografía")));
    }

    // ----------------------------------------------------------- comparador --

    public Comparacion comparar(long id, String ciudad, Long establecimientoId, int unidades) {
        if (unidades < 1 || unidades > 1000) {
            throw new ApiException(400, "Las unidades a comprar deben estar entre 1 y 1000");
        }
        ProductoDetalle producto = detalle(id);
        List<PrecioSede> filas = db.read(c -> db.list(c, "comparar_precios", Params.of()
                .bigint("producto_id", id).text("ciudad", blanco(ciudad))
                .bigint("establecimiento_id", establecimientoId).integer("dias_vigencia", diasVigencia),
                rs -> new PrecioSede(rs.getLong("reporte_id"), rs.getLong("sede_id"),
                        rs.getLong("establecimiento_id"), rs.getString("almacen"), rs.getString("sede"),
                        rs.getString("ciudad"), rs.getString("direccion"), rs.getBigDecimal("precio_cop"),
                        rs.getString("fecha"), rs.getInt("dias"), rs.getBoolean("desactualizado"),
                        rs.getBoolean("es_mas_barato"), rs.getBigDecimal("diferencia_cop"),
                        rs.getBigDecimal("diferencia_pct"))));
        return new Comparacion(producto, filas, filas.isEmpty() ? null : resumir(filas, unidades), diasVigencia);
    }

    /** Las filas llegan ordenadas de menor a mayor precio. */
    static ResumenComparacion resumir(List<PrecioSede> filas, int unidades) {
        PrecioSede barato = filas.get(0);
        PrecioSede caro = filas.get(filas.size() - 1);
        BigDecimal min = barato.precioCop();
        BigDecimal max = caro.precioCop();
        BigDecimal suma = filas.stream().map(PrecioSede::precioCop).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal promedio = suma.divide(BigDecimal.valueOf(filas.size()), 2, RoundingMode.HALF_UP);
        BigDecimal ahorro = max.subtract(min);
        BigDecimal pct = max.signum() > 0
                ? ahorro.multiply(BigDecimal.valueOf(100)).divide(max, 1, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        boolean hayViejos = filas.stream().anyMatch(PrecioSede::desactualizado);
        return new ResumenComparacion(filas.size(), min, max, promedio, barato, caro, ahorro, pct, unidades,
                ahorro.multiply(BigDecimal.valueOf(unidades)), promedio.subtract(min),
                barato.desactualizado(), hayViejos);
    }

    // ------------------------------------------------------------ historial --

    public List<Reporte> historial(long id, Long sedeId, int limite) {
        if (limite < 1 || limite > 500) {
            throw new ApiException(400, "El límite debe estar entre 1 y 500");
        }
        detalle(id); // 404 si no existe
        return db.read(c -> db.list(c, "historial_producto", Params.of().bigint("producto_id", id)
                .bigint("sede_id", sedeId).integer("dias_vigencia", diasVigencia).integer("limite", limite),
                rs -> new Reporte(rs.getLong("reporte_id"), rs.getLong("sede_id"), rs.getString("almacen"),
                        rs.getString("sede"), rs.getString("ciudad"), rs.getBigDecimal("precio_cop"),
                        rs.getString("fecha"), rs.getInt("dias"), rs.getBoolean("desactualizado"),
                        rs.getString("usuario"), rs.getBigDecimal("variacion_cop"))));
    }

    // -------------------------------------------------------------- helpers --

    private static String blanco(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static Foto decodificarFoto(String base64) {
        if (base64 == null || base64.isBlank()) {
            return null;
        }
        String s = base64.trim();
        int coma = s.indexOf(',');
        if (s.startsWith("data:") && coma > 0) {
            s = s.substring(coma + 1);
        }
        byte[] d;
        try {
            d = Base64.getMimeDecoder().decode(s);
        } catch (IllegalArgumentException e) {
            throw new ApiException(400, "La fotografía no es una imagen base64 válida");
        }
        if (d.length > MAX_FOTO_BYTES) {
            throw new ApiException(400, "La fotografía supera 1 MB; reduzca su tamaño");
        }
        String tipo = null;
        if (d.length > 12 && (d[0] & 0xFF) == 0xFF && (d[1] & 0xFF) == 0xD8 && (d[2] & 0xFF) == 0xFF) {
            tipo = "image/jpeg";
        } else if (d.length > 12 && (d[0] & 0xFF) == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G') {
            tipo = "image/png";
        } else if (d.length > 12 && d[0] == 'R' && d[1] == 'I' && d[2] == 'F' && d[3] == 'F'
                && d[8] == 'W' && d[9] == 'E' && d[10] == 'B' && d[11] == 'P') {
            tipo = "image/webp";
        }
        if (tipo == null) {
            throw new ApiException(400, "La fotografía debe ser JPEG, PNG o WEBP");
        }
        return new Foto(d, tipo);
    }
}
