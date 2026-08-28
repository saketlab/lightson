.ntl_palette <- c(
  "#0072B2",
  "#E69F00",
  "#009E73",
  "#CC79A7",
  "#56B4E9",
  "#D55E00",
  "#F0E442",
  "#999999"
)

.ntl_font <- Sys.getenv("LIGHTSON_FONT", "sans")


#' ggplot2 theme for nighttime lights plots
#'
#' A transparent-background `theme_minimal()` base tuned for NTL data: tight
#' grid, bold title, and optional overrides via `...`. Ink colour is a
#' single equal-contrast grey (`#767676`, ~4.5:1 against both pure black and
#' pure white) so the same rendered figure reads on light and dark pages
#' alike, since pkgdown bakes each figure to one static PNG at build time.
#'
#' @param base_size Base font size. Default `12`.
#' @param ... Additional [ggplot2::theme()] arguments.
#' @return A ggplot2 theme object.
#' @export
theme_ntl <- function(base_size = 12, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Install the 'ggplot2' package to use theme_ntl().", call. = FALSE)
  }
  ink <- "#767676"
  grid_col <- "#76767650"
  ggplot2::theme_minimal(base_size = base_size, base_family = .ntl_font) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      panel.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      legend.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      legend.key = ggplot2::element_rect(fill = "transparent", colour = NA),
      plot.title = ggplot2::element_text(colour = ink, face = "bold", size = base_size * 1.1),
      plot.title.position = "plot",
      plot.subtitle = ggplot2::element_text(
        colour = ink, size = base_size * 0.9, margin = ggplot2::margin(b = 8)
      ),
      plot.caption = ggplot2::element_text(
        colour = ink, size = base_size * 0.75, hjust = 1,
        margin = ggplot2::margin(t = 8)
      ),
      axis.title = ggplot2::element_text(colour = ink, size = base_size * 0.9),
      axis.text = ggplot2::element_text(colour = ink, size = base_size * 0.85),
      legend.title = ggplot2::element_text(colour = ink, size = base_size * 0.85, face = "bold"),
      legend.text = ggplot2::element_text(colour = ink, size = base_size * 0.85),
      legend.key.size = ggplot2::unit(0.9, "lines"),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = grid_col, linewidth = 0.4),
      plot.margin = ggplot2::margin(8, 12, 8, 8),
      ...
    )
}


#' Plot nighttime lights radiance trends
#'
#' Line chart of mean radiance over time for one or more regions. Accepts
#' output from [extract_panel()] or [bhuvan_stats()].
#'
#' @param panel A data frame as returned by [extract_panel()] (with `region_id`
#'   column) or [bhuvan_stats()] (with `state` column), plus `year` and
#'   `mean_radiance`.
#' @param region Character vector of region identifiers to plot. `NULL`
#'   (default) plots all regions.
#' @param title Plot title. Default `"Nighttime lights radiance"`.
#' @param subtitle Optional subtitle string.
#' @param caption Optional caption string.
#' @return A `ggplot2` object.
#' @export
#' @examples
#' \dontrun{
#' panel <- extract_panel(rasters, districts)
#' plot_ntl_trend(panel, region = "Lucknow")
#' plot_ntl_trend(panel, region = c("Mumbai", "Delhi", "Chennai"))
#' }
plot_ntl_trend <- function(panel,
                           region = NULL,
                           title = "Nighttime lights radiance",
                           subtitle = NULL,
                           caption = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Install the 'ggplot2' package to use plot_ntl_trend().", call. = FALSE)
  }
  if (!requireNamespace("scales", quietly = TRUE)) {
    stop("Install the 'scales' package to use plot_ntl_trend().", call. = FALSE)
  }

  df <- panel
  id_col <- intersect(c("region_id", "state"), names(df))[1]
  if (is.na(id_col)) stop("`panel` must have a `region_id` or `state` column.", call. = FALSE)

  if (!is.null(region)) {
    df <- df[df[[id_col]] %in% region, ]
    if (nrow(df) == 0) {
      stop("No rows found for region(s): ", paste(region, collapse = ", "), call. = FALSE)
    }
  }

  n_groups <- length(unique(df[[id_col]]))
  pal <- rep_len(.ntl_palette, n_groups)

  ggplot2::ggplot(df, ggplot2::aes(
    x      = year,
    y      = mean_radiance,
    colour = .data[[id_col]],
    group  = .data[[id_col]]
  )) +
    ggplot2::geom_line(linewidth = 0.75, alpha = 0.9) +
    ggplot2::geom_point(size = 2.2, alpha = 0.95) +
    ggplot2::scale_colour_manual(values = pal, name = NULL) +
    ggplot2::scale_x_continuous(breaks = scales::breaks_pretty(n = 6)) +
    ggplot2::scale_y_continuous(labels = scales::label_number(accuracy = 0.01)) +
    ggplot2::labs(
      x        = NULL,
      y        = "Mean radiance",
      title    = title,
      subtitle = subtitle,
      caption  = caption
    ) +
    theme_ntl() +
    ggplot2::theme(legend.position = "bottom") +
    ggplot2::guides(colour = ggplot2::guide_legend(
      nrow = 2, override.aes = list(linewidth = 1.5, size = 3)
    ))
}


.ntl_map_colours <- c(
  "#080c14",
  "#1c1a14",
  "#2e2510",
  "#5a3d08",
  "#a06010",
  "#d4920a",
  "#f0c060",
  "#fce8b0",
  "#fff8e8"
)

.ntl_bhuvan_breaks <- c(20, 80, 220)
.ntl_bhuvan_labels <- c("< 5", "5 - 25", "26 - 200", "> 200")
.ntl_bhuvan_colours <- c("#0a0a0a", "#7a7a8a", "#d4c84a", "#cc2200")

#' Plot a nighttime lights raster map
#'
#' Renders a single `SpatRaster` as a map. Two palettes are available:
#'
#' * `"glow"` (default): continuous dark-olive-to-cream-white ramp modelled on
#'   the NASA Black Marble composite. Suited to dark backgrounds and multi-panel
#'   year comparisons.
#' * `"bhuvan"`: 4-class categorical legend matching the Bhuvan portal: black
#'   (< 5 nW/cm2/sr), dark blue-grey (5-25), cream (26-200), red (> 200).
#'
#' @param raster A single-layer `SpatRaster`. Pass one element from the list
#'   returned by [ntl_download()] or [bhuvan_raster()].
#' @param polygons Optional `sf` object for boundary overlay.
#' @param title Plot title. Default `"Nighttime lights"`.
#' @param caption Optional caption string.
#' @param palette One of `"glow"` (default) or `"bhuvan"`.
#' @param dark Logical. If `TRUE`, the plot background is `#080c14` (deep navy)
#'   and text is light. Ignored when `palette = "bhuvan"` (always dark bg).
#'   Default `TRUE`.
#' @param limits Numeric vector of length 2 for the continuous scale. Only used
#'   when `palette = "glow"`. `NULL` uses the raster min/max. Set
#'   explicitly when comparing multiple panels on the same scale.
#' @return A `ggplot2` object.
#' @export
#' @examples
#' \dontrun{
#' rasters <- bhuvan_raster("IND", years = 2022, bbox_pad = c(0, 0, 0, 3.5))
#' plot_ntl_map(rasters[["2022"]], dark = TRUE)
#' plot_ntl_map(rasters[["2022"]], palette = "bhuvan")
#' }
plot_ntl_map <- function(raster,
                         polygons = NULL,
                         title = "Nighttime lights",
                         caption = NULL,
                         palette = c("glow", "bhuvan"),
                         dark = TRUE,
                         limits = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Install the 'ggplot2' package to use plot_ntl_map().", call. = FALSE)
  }
  if (!requireNamespace("scales", quietly = TRUE)) {
    stop("Install the 'scales' package to use plot_ntl_map().", call. = FALSE)
  }
  palette <- match.arg(palette)

  df <- as.data.frame(raster, xy = TRUE, na.rm = TRUE)
  val_col <- names(df)[3]
  bbox <- .region_to_bbox(raster)
  xlim <- unname(bbox[c("xmin", "xmax")])
  ylim <- unname(bbox[c("ymin", "ymax")])

  use_dark <- dark || palette == "bhuvan"

  bg_col <- if (use_dark) "#080c14" else "white"
  title_col <- if (use_dark) "#CDD9E5" else "grey10"
  cap_col <- if (use_dark) "#8B949E" else "grey50"
  leg_col <- if (use_dark) "#8B949E" else "grey30"
  leg_title <- if (use_dark) "#CDD9E5" else "grey10"
  border_col <- if (!is.null(polygons)) {
    if (use_dark) "#6b7280" else "grey40"
  } else {
    NULL
  }
  border_lwd <- if (use_dark) 0.35 else 0.25

  bg_poly <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(
    structure(
      c(xlim[1], ylim[1], xlim[2], ylim[2]),
      names = c("xmin", "ymin", "xmax", "ymax"),
      class = "bbox",
      crs = sf::st_crs(4326)
    )
  )))

  if (palette == "bhuvan") {
    df[[val_col]] <- cut(
      df[[val_col]],
      breaks = c(-Inf, .ntl_bhuvan_breaks, Inf),
      labels = .ntl_bhuvan_labels,
      right  = TRUE
    )
  }

  p_base <- ggplot2::ggplot() +
    ggplot2::geom_sf(
      data = bg_poly, fill = bg_col, colour = NA, inherit.aes = FALSE
    ) +
    ggplot2::geom_raster(
      data = df,
      ggplot2::aes(x = x, y = y, fill = .data[[val_col]])
    )

  p <- if (palette == "bhuvan") {
    p_base +
      ggplot2::scale_fill_manual(
        values = stats::setNames(.ntl_bhuvan_colours, .ntl_bhuvan_labels),
        na.value = "#9b6fc8",
        name = "NTL Radiance\n(nW/cm\u00B2/sr)",
        drop = FALSE,
        guide = ggplot2::guide_legend(
          override.aes   = list(size = 4),
          title.position = "top",
          keywidth       = ggplot2::unit(0.8, "cm"),
          keyheight      = ggplot2::unit(0.5, "cm")
        )
      )
  } else {
    p_base +
      ggplot2::scale_fill_gradientn(
        colours = .ntl_map_colours,
        limits = limits,
        oob = scales::squish,
        na.value = if (use_dark) "#080c14" else "transparent",
        name = "Luminance",
        guide = ggplot2::guide_colorbar(
          barwidth       = ggplot2::unit(0.35, "cm"),
          barheight      = ggplot2::unit(4.5, "cm"),
          ticks          = FALSE,
          title.position = "top"
        )
      )
  }

  p <- p +
    ggplot2::coord_sf(xlim = xlim, ylim = ylim, expand = FALSE) +
    ggplot2::labs(x = NULL, y = NULL, title = title, caption = caption) +
    ggplot2::theme_void(base_size = 12, base_family = .ntl_font) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      panel.background = ggplot2::element_rect(fill = bg_col, colour = NA),
      panel.border = ggplot2::element_blank(),
      panel.ontop = FALSE,
      plot.title = ggplot2::element_text(
        colour = title_col, face = "bold", size = 13,
        margin = ggplot2::margin(b = 4)
      ),
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(
        colour = cap_col, size = 9, hjust = 1,
        margin = ggplot2::margin(t = 6)
      ),
      legend.title = ggplot2::element_text(colour = leg_title, size = 9, face = "bold"),
      legend.text = ggplot2::element_text(colour = leg_col, size = 8),
      legend.key.height = ggplot2::unit(if (palette == "bhuvan") 0.5 else 1.8, "cm"),
      legend.key.width = ggplot2::unit(if (palette == "bhuvan") 0.8 else 0.35, "cm"),
      legend.position = "right",
      plot.margin = ggplot2::margin(6, 6, 6, 6)
    )

  if (!is.null(polygons)) {
    p <- suppressMessages(
      p + ggplot2::geom_sf(
        data        = polygons,
        fill        = NA,
        colour      = border_col,
        linewidth   = border_lwd,
        inherit.aes = FALSE
      )
    )
  }
  p
}


#' Plot a multi-year nighttime lights panel
#'
#' Arranges one map per year into a patchwork grid with a shared title,
#' subtitle, and caption. A shared luminance scale is computed from the
#' 99.5th percentile across all rasters so panels are directly comparable.
#'
#' Requires the \pkg{patchwork} package.
#'
#' @param rasters Named list of `SpatRaster` objects as returned by
#'   [ntl_download()] or [bhuvan_raster()], keyed by year.
#' @param polygons Optional `sf` object for boundary overlay.
#' @param title Overall plot title. Default `"India at night"`.
#' @param subtitle Optional subtitle string.
#' @param caption Optional caption string.
#' @param palette One of `"glow"` (default) or `"bhuvan"`. Passed to
#'   [plot_ntl_map()].
#' @param ncol Number of columns in the grid. Default `3`.
#' @param bg_colour Background colour of the assembled panel.
#'   Default `"#080c14"` (deep navy).
#' @param title_colour Title text colour. Default `"#CDD9E5"`.
#' @param subtitle_colour Subtitle and caption text colour. Default `"#8B949E"`.
#' @param year_colour Year label colour on each individual map.
#'   Default `"#E8A87C"` (warm amber).
#' @return A `patchwork` object.
#' @export
#' @examples
#' \dontrun{
#' rasters <- bhuvan_raster("IND", years = c(2012, 2015, 2018, 2021, 2024))
#' states <- get_india_admin("state")
#' plot_ntl_panel(rasters,
#'   polygons = states, title = "India at night, 2012-2024",
#'   caption = "Source: ISRO Bhuvan NTL portal"
#' )
#' }
plot_ntl_panel <- function(rasters,
                           polygons = NULL,
                           title = "India at night",
                           subtitle = NULL,
                           caption = NULL,
                           palette = c("glow", "bhuvan"),
                           ncol = 3L,
                           bg_colour = "#080c14",
                           title_colour = "#CDD9E5",
                           subtitle_colour = "#8B949E",
                           year_colour = "#E8A87C") {
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    stop("Install the 'patchwork' package to use plot_ntl_panel().", call. = FALSE)
  }
  palette <- match.arg(palette)

  all_vals <- unlist(lapply(rasters, function(r) terra::values(r)), use.names = FALSE)
  lim <- c(0, stats::quantile(all_vals, 0.995, na.rm = TRUE))

  panels <- lapply(names(rasters), function(yr) {
    plot_ntl_map(
      rasters[[yr]],
      polygons = polygons,
      title    = yr,
      palette  = palette,
      limits   = if (palette == "glow") lim else NULL
    ) +
      ggplot2::theme(
        legend.position = "none",
        plot.title = ggplot2::element_text(
          colour = year_colour, face = "bold", size = 12,
          hjust = 0.5, margin = ggplot2::margin(b = 4)
        )
      )
  })

  patchwork::wrap_plots(panels, ncol = ncol) +
    patchwork::plot_layout(guides = "collect") &
    patchwork::plot_annotation(
      title = title,
      subtitle = subtitle,
      caption = caption,
      theme = ggplot2::theme(
        text = ggplot2::element_text(family = .ntl_font),
        plot.background = ggplot2::element_rect(fill = bg_colour, colour = NA),
        plot.title = ggplot2::element_text(
          colour = title_colour, face = "bold", size = 15,
          margin = ggplot2::margin(b = 4)
        ),
        plot.subtitle = ggplot2::element_text(
          colour = subtitle_colour, size = 9,
          margin = ggplot2::margin(b = 8)
        ),
        plot.caption = ggplot2::element_text(
          colour = subtitle_colour, size = 8, hjust = 1,
          margin = ggplot2::margin(t = 10)
        ),
        plot.margin = ggplot2::margin(12, 12, 8, 12)
      )
    )
}
