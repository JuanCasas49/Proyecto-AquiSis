package org.acme.resource;

import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import org.acme.dto.Dtos.Opcion;
import org.acme.dto.Dtos.SedeDto;
import org.acme.dto.Dtos.UsuarioRequest;
import org.acme.dto.Dtos.UsuarioResponse;
import org.acme.service.CatalogoService;

import java.util.List;
import java.util.Map;

/** Listas de apoyo (categorías, marcas, almacenes, sedes, ciudades), usuarios y estado de la conexión. */
@Path("/api")
@Produces(MediaType.APPLICATION_JSON)
public class CatalogoResource {

    @Inject
    CatalogoService service;

    @GET
    @Path("/categorias")
    public List<Opcion> categorias() {
        return service.categorias();
    }

    @GET
    @Path("/marcas")
    public List<Opcion> marcas() {
        return service.marcas();
    }

    @GET
    @Path("/establecimientos")
    public List<Opcion> establecimientos() {
        return service.establecimientos();
    }

    @GET
    @Path("/ciudades")
    public List<String> ciudades() {
        return service.ciudades();
    }

    @GET
    @Path("/sedes")
    public List<SedeDto> sedes(@QueryParam("establecimientoId") Long establecimientoId,
                               @QueryParam("ciudad") String ciudad) {
        return service.sedes(establecimientoId, ciudad);
    }

    /**
     * Registro/identificación ligera por correo (sin contraseña). Sirve para atribuir los
     * reportes de precio; NO es autenticación segura (ver README).
     */
    @POST
    @Path("/usuarios")
    @Consumes(MediaType.APPLICATION_JSON)
    public UsuarioResponse registrarUsuario(@Valid UsuarioRequest request) {
        return service.registrarUsuario(request);
    }

    /** Verifica la conexión con Neon. */
    @GET
    @Path("/salud")
    public Map<String, Object> salud() {
        return service.salud();
    }
}
