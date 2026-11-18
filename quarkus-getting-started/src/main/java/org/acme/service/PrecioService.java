package org.acme.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.acme.ApiException;
import org.acme.db.Db;
import org.acme.db.Params;
import org.acme.dto.Dtos.Foto;
import org.acme.dto.Dtos.ReporteUsuario;
import org.acme.dto.Dtos.ResultadoModeracion;
import org.acme.dto.Dtos.UsuarioResponse;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Set;

/**
 * HU-08: seguimiento de los reportes colaborativos (pendiente / validado / rechazado), evidencia fotográfica
 * y validación por moderadores.
 */
@ApplicationScoped
public class PrecioService {

    private static final Set<String> ESTADOS = Set.of("pendiente", "validado", "rechazado");

    @Inject
    Db db;

    @Inject
    CatalogoService catalogo;

    private static ReporteUsuario mapear(ResultSet rs) throws SQLException {
        return new ReporteUsuario(rs.getLong("reporte_id"), rs.getLong("producto_id"), rs.getString("producto"),
                rs.getString("almacen"), rs.getString("sede"), rs.getString("ciudad"), rs.getBigDecimal("precio_cop"),
                rs.getString("fecha"), rs.getString("estado"), rs.getBoolean("tiene_evidencia"),
                rs.getString("motivo_rechazo"), rs.getString("usuario"));
    }

    /** Reportes enviados por un usuario, opcionalmente filtrados por estado. */
    public List<ReporteUsuario> reportesDeUsuario(long usuarioId, String estado, int limite) {
        String est = estado == null || estado.isBlank() ? null : estado.trim().toLowerCase();
        if (est != null && !ESTADOS.contains(est)) {
            throw new ApiException(400, "Estado inválido. Use: pendiente, validado o rechazado");
        }
        if (limite < 1 || limite > 200) {
            throw new ApiException(400, "El límite debe estar entre 1 y 200");
        }
        catalogo.usuarioPorId(usuarioId); // 404 si no existe
        return db.read(c -> db.list(c, "mis_reportes",
                Params.of().bigint("usuario_id", usuarioId).text("estado", est).integer("limite", limite),
                PrecioService::mapear));
    }

    private void exigirModerador(Long usuarioId) {
        if (usuarioId == null) {
            throw new ApiException(400, "Debe identificarse (usuarioId)");
        }
        UsuarioResponse u = catalogo.usuarioPorId(usuarioId);
        if (!"moderador".equals(u.rol())) {
            throw new ApiException(403, "Solo un moderador puede validar precios");
        }
    }

    /** Cola de moderación (solo moderadores): reportes pendientes, los más antiguos primero. */
    public List<ReporteUsuario> pendientes(Long moderadorId, int limite) {
        exigirModerador(moderadorId);
        if (limite < 1 || limite > 200) {
            throw new ApiException(400, "El límite debe estar entre 1 y 200");
        }
        return db.read(c -> db.list(c, "reportes_pendientes", Params.of().integer("limite", limite),
                PrecioService::mapear));
    }

    public ResultadoModeracion validar(long reporteId, Long moderadorId) {
        if (moderadorId == null) {
            throw new ApiException(400, "Debe identificarse (usuarioId)");
        }
        db.tx(c -> db.one(c, "validar_reporte", Params.of().bigint("reporte_id", reporteId)
                .bigint("usuario_id", moderadorId), rs -> rs.getBoolean("ok")).orElseThrow());
        return new ResultadoModeracion(reporteId, "validado");
    }

    public ResultadoModeracion rechazar(long reporteId, Long moderadorId, String motivo) {
        if (moderadorId == null) {
            throw new ApiException(400, "Debe identificarse (usuarioId)");
        }
        db.tx(c -> db.one(c, "rechazar_reporte", Params.of().bigint("reporte_id", reporteId)
                .bigint("usuario_id", moderadorId).text("motivo", motivo), rs -> rs.getBoolean("ok")).orElseThrow());
        return new ResultadoModeracion(reporteId, "rechazado");
    }

    public Foto evidencia(long reporteId) {
        return db.read(c -> db.one(c, "evidencia_reporte", Params.of().bigint("reporte_id", reporteId),
                rs -> new Foto(rs.getBytes("evidencia"), rs.getString("evidencia_tipo")))
                .orElseThrow(() -> new ApiException(404, "El reporte no tiene evidencia fotográfica")));
    }
}
