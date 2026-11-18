package org.acme.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.acme.ApiException;
import org.acme.db.Db;
import org.acme.db.Params;
import org.acme.dto.Dtos.ItemLista;
import org.acme.dto.Dtos.ItemListaRequest;
import org.acme.dto.Dtos.CantidadRequest;
import org.acme.dto.Dtos.LineaValoracion;
import org.acme.dto.Dtos.ListaDetalle;
import org.acme.dto.Dtos.ListaRequest;
import org.acme.dto.Dtos.ListaResumen;
import org.acme.dto.Dtos.ResumenValoracion;
import org.acme.dto.Dtos.SupermercadoValoracion;
import org.acme.dto.Dtos.Valoracion;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * HU-06 (listas de mercado) y HU-07 (valor total y ahorro por supermercado).
 * Cada operación exige el usuarioId dueño de la lista: una lista ajena responde 404.
 */
@ApplicationScoped
public class ListaService {

    @Inject
    Db db;

    @ConfigProperty(name = "app.precios.dias-vigencia", defaultValue = "30")
    int diasVigencia;

    /** Fila del resultado de lista_valoracion.sql: un producto de la lista en un supermercado. */
    record FilaPrecio(long productoId, int cantidad, long establecimientoId, String almacen, BigDecimal precio,
                      String sede, String ciudad, String fecha, Integer dias) {
    }

    private static long usuario(Long usuarioId) {
        if (usuarioId == null) {
            throw new ApiException(400, "Debe identificarse (usuarioId)");
        }
        return usuarioId;
    }

    // ------------------------------------------------------------- HU-06 ---

    public List<ListaResumen> listar(Long usuarioId) {
        long u = usuario(usuarioId);
        return db.read(c -> listasDe(c, u));
    }

    private List<ListaResumen> listasDe(Connection c, long usuarioId) throws SQLException {
        return db.list(c, "listas_usuario", Params.of().bigint("usuario_id", usuarioId),
                rs -> new ListaResumen(rs.getLong("id"), rs.getString("nombre"), rs.getInt("n_productos"),
                        rs.getLong("n_unidades"), rs.getString("actualizada")));
    }

    public ListaResumen crear(ListaRequest r) {
        return db.tx(c -> {
            long id = db.one(c, "crear_lista", Params.of().bigint("usuario_id", r.usuarioId()).text("nombre", r.nombre()),
                    rs -> rs.getLong("id")).orElseThrow();
            return listasDe(c, r.usuarioId()).stream().filter(l -> l.id() == id).findFirst().orElseThrow();
        });
    }

    public ListaResumen renombrar(long listaId, ListaRequest r) {
        return db.tx(c -> {
            db.one(c, "renombrar_lista", Params.of().bigint("lista_id", listaId).bigint("usuario_id", r.usuarioId())
                    .text("nombre", r.nombre()), rs -> rs.getBoolean("ok")).orElseThrow();
            return listasDe(c, r.usuarioId()).stream().filter(l -> l.id() == listaId).findFirst().orElseThrow();
        });
    }

    public void eliminar(long listaId, Long usuarioId) {
        long u = usuario(usuarioId);
        db.tx(c -> db.one(c, "eliminar_lista", Params.of().bigint("lista_id", listaId).bigint("usuario_id", u),
                rs -> rs.getBoolean("ok")).orElseThrow());
    }

    public ListaDetalle detalle(long listaId, Long usuarioId) {
        long u = usuario(usuarioId);
        return db.read(c -> {
            String nombre = cabecera(c, listaId, u);
            List<ItemLista> items = items(c, listaId);
            return new ListaDetalle(listaId, nombre, items, items.size(), unidades(items));
        });
    }

    private String cabecera(Connection c, long listaId, long usuarioId) throws SQLException {
        return db.one(c, "lista_cabecera", Params.of().bigint("lista_id", listaId).bigint("usuario_id", usuarioId),
                rs -> rs.getString("nombre")).orElseThrow(() -> new ApiException(404, "La lista no existe"));
    }

    private List<ItemLista> items(Connection c, long listaId) throws SQLException {
        return db.list(c, "lista_items", Params.of().bigint("lista_id", listaId),
                rs -> new ItemLista(rs.getLong("producto_id"), rs.getString("nombre"), rs.getString("marca"),
                        rs.getString("presentacion"), rs.getBigDecimal("cantidad_producto"), rs.getString("unidad"),
                        rs.getBoolean("tiene_foto"), rs.getInt("cantidad")));
    }

    private static long unidades(List<ItemLista> items) {
        return items.stream().mapToLong(ItemLista::cantidad).sum();
    }

    /** Agrega un producto; si ya estaba en la lista, suma las cantidades (máximo 999). */
    public ItemLista agregarItem(long listaId, ItemListaRequest r) {
        return db.tx(c -> {
            db.one(c, "agregar_item_lista", Params.of().bigint("lista_id", listaId).bigint("usuario_id", r.usuarioId())
                    .bigint("producto_id", r.productoId()).integer("cantidad", r.cantidad()),
                    rs -> rs.getInt("cantidad")).orElseThrow();
            return itemDe(c, listaId, r.productoId());
        });
    }

    public ItemLista modificarCantidad(long listaId, long productoId, CantidadRequest r) {
        return db.tx(c -> {
            db.one(c, "modificar_item_lista", Params.of().bigint("lista_id", listaId).bigint("usuario_id", r.usuarioId())
                    .bigint("producto_id", productoId).integer("cantidad", r.cantidad()),
                    rs -> rs.getInt("cantidad")).orElseThrow();
            return itemDe(c, listaId, productoId);
        });
    }

    public void quitarItem(long listaId, long productoId, Long usuarioId) {
        long u = usuario(usuarioId);
        db.tx(c -> db.one(c, "quitar_item_lista", Params.of().bigint("lista_id", listaId).bigint("usuario_id", u)
                .bigint("producto_id", productoId), rs -> rs.getBoolean("ok")).orElseThrow());
    }

    private ItemLista itemDe(Connection c, long listaId, long productoId) throws SQLException {
        return items(c, listaId).stream().filter(i -> i.productoId() == productoId).findFirst().orElseThrow();
    }

    // ------------------------------------------------------------- HU-07 ---

    public Valoracion valoracion(long listaId, Long usuarioId, String ciudad) {
        long u = usuario(usuarioId);
        String ciu = ciudad == null || ciudad.isBlank() ? null : ciudad.trim();
        return db.read(c -> {
            String nombre = cabecera(c, listaId, u);
            List<ItemLista> items = items(c, listaId);
            List<FilaPrecio> filas = db.list(c, "lista_valoracion",
                    Params.of().bigint("lista_id", listaId).text("ciudad", ciu),
                    rs -> new FilaPrecio(rs.getLong("producto_id"), rs.getInt("cantidad"),
                            rs.getLong("establecimiento_id"), rs.getString("almacen"), rs.getBigDecimal("precio_cop"),
                            rs.getString("sede"), rs.getString("ciudad"), rs.getString("fecha"),
                            Db.intOrNull(rs, "dias")));
            return armar(listaId, nombre, items, filas, ciu, diasVigencia);
        });
    }

    /**
     * Calcula, por supermercado, el total de la lista (suma de precio vigente x cantidad) y el ahorro de elegir
     * el más económico frente al más costoso. Solo se comparan supermercados "completos" (con precio para todos
     * los productos); los incompletos se muestran con su total parcial y los productos que les faltan.
     */
    static Valoracion armar(long listaId, String nombre, List<ItemLista> items, List<FilaPrecio> filas,
                            String ciudad, int diasVigencia) {
        Map<Long, List<FilaPrecio>> porMercado = new LinkedHashMap<>();
        for (FilaPrecio f : filas) {
            porMercado.computeIfAbsent(f.establecimientoId(), k -> new ArrayList<>()).add(f);
        }
        List<SupermercadoValoracion> mercados = new ArrayList<>();
        for (List<FilaPrecio> delMercado : porMercado.values()) {
            Map<Long, FilaPrecio> porProducto = new HashMap<>();
            for (FilaPrecio f : delMercado) {
                porProducto.put(f.productoId(), f);
            }
            List<LineaValoracion> lineas = new ArrayList<>();
            List<String> sinPrecio = new ArrayList<>();
            BigDecimal total = BigDecimal.ZERO;
            boolean viejos = false;
            for (ItemLista it : items) {
                FilaPrecio f = porProducto.get(it.productoId());
                if (f == null || f.precio() == null) {
                    sinPrecio.add(it.nombre());
                    lineas.add(new LineaValoracion(it.productoId(), it.nombre(), it.cantidad(), null, null,
                            null, null, null, null, false));
                    continue;
                }
                BigDecimal subtotal = f.precio().multiply(BigDecimal.valueOf(it.cantidad()));
                boolean viejo = f.dias() != null && f.dias() > diasVigencia;
                viejos |= viejo;
                total = total.add(subtotal);
                lineas.add(new LineaValoracion(it.productoId(), it.nombre(), it.cantidad(), f.precio(), subtotal,
                        f.sede(), f.ciudad(), f.fecha(), f.dias(), viejo));
            }
            FilaPrecio cualquiera = delMercado.get(0);
            boolean completo = sinPrecio.isEmpty() && !items.isEmpty();
            mercados.add(new SupermercadoValoracion(cualquiera.establecimientoId(), cualquiera.almacen(),
                    total.setScale(2, RoundingMode.HALF_UP), completo, items.size() - sinPrecio.size(), sinPrecio,
                    false, null, null, viejos, lineas));
        }

        // Los completos (comparables) primero, de menor a mayor total; luego los incompletos por productos faltantes
        List<SupermercadoValoracion> comparables = mercados.stream().filter(SupermercadoValoracion::completo)
                .sorted(Comparator.comparing(SupermercadoValoracion::total)
                        .thenComparing(SupermercadoValoracion::almacen)).toList();
        List<SupermercadoValoracion> incompletos = mercados.stream().filter(m -> !m.completo())
                .sorted(Comparator.comparingInt((SupermercadoValoracion m) -> m.productosSinPrecio().size())
                        .thenComparing(SupermercadoValoracion::total)
                        .thenComparing(SupermercadoValoracion::almacen)).toList();

        List<SupermercadoValoracion> ordenados = new ArrayList<>();
        ResumenValoracion resumen;
        if (comparables.isEmpty()) {
            ordenados.addAll(incompletos);
            resumen = new ResumenValoracion(0, null, null, null, null, BigDecimal.ZERO, BigDecimal.ZERO,
                    mercados.stream().anyMatch(SupermercadoValoracion::hayDesactualizados));
        } else {
            SupermercadoValoracion barato = comparables.get(0);
            SupermercadoValoracion caro = comparables.get(comparables.size() - 1);
            BigDecimal min = barato.total();
            BigDecimal max = caro.total();
            BigDecimal ahorro = max.subtract(min);
            BigDecimal pct = max.signum() > 0
                    ? ahorro.multiply(BigDecimal.valueOf(100)).divide(max, 1, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;
            for (SupermercadoValoracion m : comparables) {
                BigDecimal dif = m.total().subtract(min);
                BigDecimal difPct = min.signum() > 0
                        ? dif.multiply(BigDecimal.valueOf(100)).divide(min, 1, RoundingMode.HALF_UP)
                        : BigDecimal.ZERO;
                ordenados.add(new SupermercadoValoracion(m.establecimientoId(), m.almacen(), m.total(), true,
                        m.productosConPrecio(), m.productosSinPrecio(), m.total().compareTo(min) == 0, dif, difPct,
                        m.hayDesactualizados(), m.lineas()));
            }
            ordenados.addAll(incompletos);
            resumen = new ResumenValoracion(comparables.size(), barato.almacen(), min, caro.almacen(), max,
                    ahorro, pct, mercados.stream().anyMatch(SupermercadoValoracion::hayDesactualizados));
        }

        List<String> sinPrecioEnNingunLado = new ArrayList<>();
        for (ItemLista it : items) {
            boolean algunPrecio = filas.stream().anyMatch(f -> f.productoId() == it.productoId() && f.precio() != null);
            if (!algunPrecio) {
                sinPrecioEnNingunLado.add(it.nombre());
            }
        }
        long unidades = items.stream().mapToLong(ItemLista::cantidad).sum();
        return new Valoracion(listaId, nombre, items.size(), unidades, ciudad, diasVigencia, ordenados, resumen,
                sinPrecioEnNingunLado);
    }
}
