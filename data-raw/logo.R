# Builds man/figures/logo.png from real ISRO Bhuvan 2024 nighttime lights.
library(ggplot2)
devtools::load_all(quiet = TRUE)

sysfonts::font_add_google("Albert Sans", "albert", regular.wt = 500)
showtext::showtext_auto()

r <- bhuvan_raster("IND", years = 2024, bbox_pad = c(0, 0, 0, 3.5))[["2024"]]
res <- terra::res(r)
df <- as.data.frame(r, xy = TRUE, na.rm = TRUE)
names(df)[3] <- "radiance"
# land from the bundled boundary so watermark NAs leave no holes
lit <- df[df$radiance >= 112.5, ]
hot <- df[df$radiance >= 200, ]
sf::sf_use_s2(FALSE) # planar union; the bundled LGD geometries trip s2
land <- sf::st_union(sf::st_make_valid(get_india_admin("state")))
# outer rings only; inter-state slivers survive the union as holes
land <- sf::st_cast(sf::st_collection_extract(land, "POLYGON"), "POLYGON")
land <- sf::st_sfc(lapply(land, function(p) sf::st_polygon(p[1])), crs = 4326)

map <- ggplot() +
  geom_sf(data = land, fill = "#171e2c", colour = NA) +
  geom_point(data = lit, aes(x, y), colour = "#f0a53a", size = 0.25, alpha = 0.07, stroke = 0) +
  geom_tile(data = lit, aes(x, y), fill = "#f2b04c", width = res[1], height = res[2]) +
  geom_tile(data = hot, aes(x, y), fill = "#fff3d1", width = res[1], height = res[2]) +
  geom_sf(data = land, fill = NA, colour = "#eef1f6", linewidth = 0.16) +
  # frame on India's bbox so s_x = 1 centres it on the hex
  coord_sf(
    crs = 4326, expand = FALSE,
    xlim = sf::st_bbox(land)[c("xmin", "xmax")], ylim = sf::st_bbox(land)[c("ymin", "ymax")]
  ) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA)
  )

hexSticker::sticker(
  map,
  # largest size keeping ~55 px clear at J&K
  s_x = 1, s_y = 1.06, s_width = 1.27, s_height = 1.27,
  package = "lightson", p_family = "albert", p_color = "#f4eee4",
  p_size = 17, p_y = 0.31,
  h_fill = "#0b0f19", h_color = "#3a465c", h_size = 0.7,
  filename = "man/figures/logo.png", dpi = 600
)
