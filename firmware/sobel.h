// =============================================================================
// sobel.h -- driver C del peripheral de filtro de imagen (Sobel compass + Canny)
//   memory-mapped en 0x0045 del FemtoRV32 (ver peripheral_sobel.v).
//   Modelo pixel-a-pixel (polling): se alimenta un frame en raster y se leen
//   los resultados interiores en orden.
// =============================================================================
#ifndef SOBEL_H
#define SOBEL_H

#define SOBEL_BASE    0x00450000u
#define SOBEL_CTRL    (*(volatile unsigned int*)(SOBEL_BASE + 0x00)) // W: bit0=mode, bit1=frame_reset
#define SOBEL_IMGW    (*(volatile unsigned int*)(SOBEL_BASE + 0x04)) // W: ancho de imagen
#define SOBEL_LOW     (*(volatile unsigned int*)(SOBEL_BASE + 0x08)) // W: umbral bajo (canny)
#define SOBEL_HIGH    (*(volatile unsigned int*)(SOBEL_BASE + 0x0C)) // W: umbral alto (canny)
#define SOBEL_PIXEL   (*(volatile unsigned int*)(SOBEL_BASE + 0x10)) // W: 1 pixel gris -> px_valid
#define SOBEL_STATUS  (*(volatile unsigned int*)(SOBEL_BASE + 0x14)) // R: bit0 = result_ready
#define SOBEL_RESULT  (*(volatile unsigned int*)(SOBEL_BASE + 0x18)) // R: resultado (limpia ready)

#define SOBEL_MODE_COMPASS 0
#define SOBEL_MODE_CANNY   1

// configura el filtro y reinicia el frame (limpia line buffers/contadores)
static inline void sobel_init(int mode, int width, int low, int high) {
    SOBEL_IMGW = width;
    SOBEL_LOW  = low;
    SOBEL_HIGH = high;
    SOBEL_CTRL = (mode & 1) | 0x2;   // fija modo + pulso frame_reset
}

// alimenta un frame (img en raster, npx pixeles); out[] recibe los resultados
// interiores en orden. Devuelve cuantos resultados se leyeron.
static int sobel_run_frame(const unsigned char *img, int npx, unsigned int *out) {
    int n = 0, i, k;
    for (i = 0; i < npx; i++) {
        SOBEL_PIXEL = img[i];
        for (k = 0; k < 8; k++) {            // poll breve por un resultado listo
            if (SOBEL_STATUS & 1u) { out[n++] = SOBEL_RESULT; break; }
        }
    }
    return n;
}

// --- decodificacion de RESULT ---
//   compass:  mag = SOBEL_MAG(r);  dir = SOBEL_DIR(r)   (0=N..7=NW)
//   canny:    edge = SOBEL_EDGE(r); clase = SOBEL_CLASS(r) (0 nada/1 debil/2 fuerte)
#define SOBEL_MAG(r)   ((r) & 0xFF)
#define SOBEL_DIR(r)   (((r) >> 8) & 0x7)
#define SOBEL_EDGE(r)  ((r) & 0x1)
#define SOBEL_CLASS(r) (((r) >> 1) & 0x3)

#endif // SOBEL_H
