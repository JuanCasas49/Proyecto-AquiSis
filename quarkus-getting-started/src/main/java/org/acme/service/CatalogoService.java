package org.acme.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.acme.ApiException;
import org.acme.db.Db;
import org.acme.db.Params;
import org.acme.dto.Dtos.Opcion;
import org.acme.dto.Dtos.SedeDto;
import org.acme.dto.Dtos.UsuarioRequest;
import org.acme.dto.Dtos.UsuarioResponse;

import java.util.List;
import java.util.Map;

@ApplicationScoped
public class CatalogoService {

    @Inject
    Db db;

    public List<Opcion> categorias() {
        return opciones("categorias");
    }

    public List<Opcion> marcas() {
        return opciones("marcas");
    }

    public List<Opcion> establecimientos() {
        return opciones("establecimientos");
    }

    private List<Opcion> opciones(String consulta) {
        return db.read(c -> db.list(c, consulta, Params.of(),
                rs -> new Opcion(rs.getLong("id"), rs.getString("nombre"))));
    }

    public List<String> ciudades() {
        return db.read(c -> db.list(c, "ciudades", Params.of(), rs -> rs.getString("ciudad")));
    }

    public List<SedeDto> sedes(Long establecimientoId, String ciudad) {
        String ciu = ciudad == null || ciudad.isBlank() ? null : ciudad.trim();
        return db.read(c -> db.list(c, "sedes",
                Params.of().bigint("establecimiento_id", establecimientoId).text("ciudad", ciu),
                rs -> new SedeDto(rs.getLong("id"), rs.getLong("establecimiento_id"), rs.getString("almacen"),
                        rs.getString("nombre"), rs.getString("ciudad"), rs.getString("direccion"))));
    }

    /** Crea el usuario o, si el correo ya existe, actualiza su nombre y lo devuelve. */
    public UsuarioResponse registrarUsuario(UsuarioRequest r) {
        return db.tx(c -> db.one(c, "crear_usuario",
                Params.of().text("nombre", r.nombre().trim()).text("email", r.email().trim()),
                rs -> new UsuarioResponse(rs.getLong("id"), rs.getString("nombre"), rs.getString("email")))
                .orElseThrow(() -> new ApiException(500, "No se pudo registrar el usuario")));
    }

    /** Comprueba la conexión con Neon y devuelve conteos básicos. */
    public Map<String, Object> salud() {
        return db.read(c -> {
            try (var st = c.createStatement();
                 var rs = st.executeQuery("SELECT (SELECT count(*) FROM productos) AS productos, "
                         + "(SELECT count(*) FROM reportes_precio) AS reportes, "
                         + "(SELECT count(*) FROM usuarios) AS usuarios")) {
                rs.next();
                return Map.<String, Object>of("estado", "ok", "baseDeDatos", "conectada",
                        "productos", rs.getLong("productos"), "reportes", rs.getLong("reportes"),
                        "usuarios", rs.getLong("usuarios"));
            }
        });
    }
}
