library(tidyverse)
library(magrittr)
library(sf)
library(terra)
library(furrr)

terra::setGDALconfig("GDAL_CACHE_MAX", 32000000)

update_aws <- FALSE

dir.create("data",
           showWarnings = FALSE)

noaa_paleo_bocinsky2016 <-
  "https://www.ncei.noaa.gov/pub/data/paleo/treering/reconstructions/northamerica/usa/bocinsky2016/"

system2(
  "wget2", 
  args = 
    c(
      "-q",            # quiet
      "-r",            # recursive
      "-np",           # no parent
      "-nH",           # don't create host directories
      "--cut-dirs=8",  # skip this many path components
      "-c",            # continue downloads
      "-nc",           # no clobber
      "-R", "index.html,bocinsky2016,robots.txt,readme-bocinsky2016.txt",  # reject matching files
      "--max-threads=8", # wget2 parallelization
      "-P", "data",     # destination directory
      noaa_paleo_bocinsky2016            # the URL to mirror
    )
)

write_paleocar_cube <-
  function(rast,
           outfile){
    if(file.exists(outfile))
      return(outfile)
    
    out <-
      terra::writeRaster(
      rast,
      filename = 
        outfile,
      overwrite = FALSE,
      datatype = "INT4U",
      filetype = "COG",
      gdal = 
        c(
          "BLOCKSIZE=128",
          "COMPRESS=ZSTD", 
          "LEVEL=1",
          "PREDICTOR=2",
          "BIGTIFF=YES",
          "SPARSE_OK=TRUE",
          "STATISTICS=YES",
          "TFW=NO",
          "OVERVIEWS=NONE",
          "NUM_THREADS=ALL_CPUS"
        )
    )
    
    return(outfile)
  }

tibble::tibble(
  path = list.files(
    "data",
    full.names = TRUE
  )
) |>
  dplyr::mutate(
    element = 
      dplyr::case_when(
        stringr::str_detect(path, "GDD") ~ "gdd_maize_maysept",
        stringr::str_detect(path, "PPT") ~ "ppt_wateryear"
      )
  ) |>
  dplyr::summarise(
    raster = list(
      terra::vrt(path) |>
        magrittr::set_names(
          stringr::str_pad(1:2000, width = 4, pad = "0")
          )
      ),
    .by = element
  ) %>%
  { purrr::walk(
    file.path(
      "paleocar_v2",
      .$element), 
    dir.create,
    recursive = TRUE,
    showWarnings = FALSE); . } |> # side effect, then pass data through unchanged
  dplyr::rowwise() |>
  dplyr::mutate(
    outfile = 
      write_paleocar_cube(
        rast = raster,
        outfile = 
          file.path(
            "paleocar_v2",
            element,
            "prediction_scaled.tif"
          )
      )
  )

if(update_aws){
  # Upload a file to S3 using multipart upload.
  
  # keyring::key_set("aws_access_key_id")
  # keyring::key_set("aws_secret_access_key")
  
  aws_s3 <-
    paws::s3(credentials =
               list(creds = list(
                 access_key_id = keyring::key_get("aws_access_key_id"),
                 secret_access_key = keyring::key_get("aws_secret_access_key")
               )))
  
  #' Upload a file to S3 using multipart upload
  #'
  #' @param client A Paws S3 client object, e.g. from `paws::s3()`.
  #' @param file The path to the file to be uploaded.
  #' @param bucket The name of the S3 bucket to be uploaded to, e.g. `my-bucket`.
  #' @param key The name to assign to the file in the S3 bucket, e.g. `path/to/file`.
  upload <- function(client, file, bucket, key) {
    multipart <- client$create_multipart_upload(
      Bucket = bucket,
      Key = key
    )
    resp <- NULL
    on.exit({
      if (is.null(resp) || inherits(resp, "try-error")) {
        client$abort_multipart_upload(
          Bucket = bucket,
          Key = key,
          UploadId = multipart$UploadId
        )
      }
    })
    resp <- try({
      parts <- upload_multipart_parts(client, file, bucket, key, multipart$UploadId)
      client$complete_multipart_upload(
        Bucket = bucket,
        Key = key,
        MultipartUpload = list(Parts = parts),
        UploadId = multipart$UploadId
      )
    })
    return(resp)
  }
  
  upload_multipart_parts <- function(client, file, bucket, key, upload_id) {
    file_size <- file.size(file)
    megabyte <- 2^20
    part_size <- 5 * megabyte
    num_parts <- ceiling(file_size / part_size)
    
    con <- base::file(file, open = "rb")
    on.exit({
      close(con)
    })
    pb <- utils::txtProgressBar(min = 0, max = num_parts)
    parts <- list()
    for (i in 1:num_parts) {
      part <- readBin(con, what = "raw", n = part_size)
      part_resp <- client$upload_part(
        Body = part,
        Bucket = bucket,
        Key = key,
        PartNumber = i,
        UploadId = upload_id
      )
      parts <- c(parts, list(list(ETag = part_resp$ETag, PartNumber = i)))
      utils::setTxtProgressBar(pb, i)
    }
    close(pb)
    return(parts)
  }
  
  plan(future.mirai::mirai_multisession,
       workers = parallel::detectCores())
  
  uploads <-
    list.files("paleocar_v2",
               full.names = TRUE,
               recursive = TRUE) %>%
    furrr::future_map(\(x){
      tryCatch(
        upload(aws_s3,
               file = x,
               bucket = "skope", 
               key = x),
        error = function(e){as.character(e)})
      
    },
    .env_globals = globalenv(),
    .options = furrr::furrr_options(seed = TRUE,
                                    scheduling = FALSE),
    
    .progress = TRUE)
  
  plan(sequential)
  
}

