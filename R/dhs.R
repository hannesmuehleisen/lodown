get_catalog_dhs <-
	function( data_name = "dhs" , output_dir , ... ){

		catalog <- NULL
		
		tf <- tempfile()
		
		if( !( 'your_email' %in% names(list(...)) ) ) stop( "`your_email` parameter must be specified.  create an account at https://dhsprogram.com/data/new-user-registration.cfm" )
		
		your_email <- list(...)[["your_email"]]

		if( !( 'your_password' %in% names(list(...)) ) ) stop( "`your_password` parameter must be specified.  create an account at https://dhsprogram.com/data/new-user-registration.cfm" )
		
		your_password <- list(...)[["your_password"]]

		if( !( 'your_project' %in% names(list(...)) ) ) stop( "`your_project` parameter must be specified.  create an account at https://dhsprogram.com/data/new-user-registration.cfm" )
		
		your_project <- list(...)[["your_project"]]

		values <- dhs_authenticate( your_email , your_password , your_project )
		
		project.number <- values$proj_id
		
		# re-access the download-datasets page
		z <- httr::POST( "https://dhsprogram.com/data/dataset_admin/download-datasets.cfm" , body = list( proj_id = project.number ) )

		# write the information from the `countries` page to a local file
		writeBin( z$content , tf )

		# load the text 
		y <- readLines( tf , warn = FALSE )

		# figure out the country lines
		country_lines <- unique( grep( 'notranslate' , y , value = TRUE ) )

		# figure out which countries are available for download
		country.names <- gsub( "(.*)>(.*)<(.*)" , "\\2" , country_lines )
		country.numbers <- gsub( '(.*)value = \"(.*)\"(.*)' , "\\2" , country_lines )


		# loop through each available country #
		for ( j in seq( length( country.numbers ) ) ){

			# extract the current country number..
			this.number <- country.numbers[ j ]
			# ..and current country name
			this.name <- country.names[ j ] 

			# create the country directory on the local disk
			# dir.create( paste0( "./" , this.name ) )


		
			# create a website key pointing the specific country
			values <- 
				list( 
					proj_id = project.number ,
					Apr_Ctry_list_id = this.number ,
					submitted = 2 ,
					action = "View Surveys" ,
					submit = "View Surveys"
				)

			# re-access the download data page
			# using the new country-specific key
			z <- httr::POST( "https://dhsprogram.com/data/dataset_admin/download-datasets.cfm" , body = values )
				
			# pull all links
			link.urls <- XML::xpathSApply( XML::htmlParse( httr::content( z ) ) , "//a" , XML::xmlGetAttr , "href" )

			# extract all links containing the current country's name
			valid.surveys <- grep( "?flag=1" , link.urls )
			link.urls <- unlist( link.urls [ valid.surveys ] )
			
			# loop through each available data set within the country #
			for ( this.link in link.urls ){

				# access each dataset's link
				z <- httr::GET( paste0( "https://dhsprogram.com" , this.link ) )

				writeBin( z$content , tf )
				
				# read the table from each country page, remove the country name, and remove extraneous characters
				this.title <- gsub( ": |," , "" , gsub( this.name , "" , gsub( '(.*)surveyTitle\">(.*)<(.*)' , "\\2" , grep( 'surveyTitle\">' , readLines( tf , warn = FALSE ) , value = TRUE ) ) ) )

				# create a dataset-specific folder within the country folder within the current working directory
				# dir.create( paste0( "./" , this.name , "/" , this.title ) )

				# store all dataset-specific links
				all.links <- XML::xpathSApply( XML::htmlParse( httr::content( z ) ) , "//div//a" , XML::xmlGetAttr , "href" )

				# keep only /data/dataset/ links
				data.link <- unique( all.links[ grepl( "customcf/legacy/data/download_dataset" , all.links ) ] )

				# directory path
				# this_dir <- paste0( "./" , this.name , "/" , this.title )
				
				for( file.url in unlist( data.link ) ){
					
					this_catalog <-
						data.frame(
							country = this.name ,
							year = substr( gsub( "[^0-9]" , "" , this.title ) , 1 , 4 ) ,
							proj_id = project.number ,
							Apr_Ctry_list_id = this.number ,
							output_filename = paste0( output_dir , "/" , this.name , "/" , this.title , "/" , gsub( "(.*)Filename=(.*)\\.(ZIP|zip)(.*)" , "\\2.zip" , file.url ) ) ,
							full_url = paste0( "https://dhsprogram.com" , file.url ) ,
							stringsAsFactors = FALSE
						)		
					
					catalog <- rbind( catalog , this_catalog )
				
				}
			}
		}

		catalog$output_folder <- gsub( "\\.zip" , "" , catalog$output_filename , ignore.case = TRUE )
		
		unique( catalog )

	}


lodown_dhs <-
	function( data_name = "dhs" , catalog , ... ){

		if( !( 'your_email' %in% names(list(...)) ) ) stop( "`your_email` parameter must be specified.  create an account at https://dhsprogram.com/data/new-user-registration.cfm" )
		
		your_email <- list(...)[["your_email"]]

		if( !( 'your_password' %in% names(list(...)) ) ) stop( "`your_password` parameter must be specified.  create an account at https://dhsprogram.com/data/new-user-registration.cfm" )
		
		your_password <- list(...)[["your_password"]]

		if( !( 'your_project' %in% names(list(...)) ) ) stop( "`your_project` parameter must be specified.  create an account at https://dhsprogram.com/data/new-user-registration.cfm" )
		
		your_project <- list(...)[["your_project"]]

		values <- dhs_authenticate( your_email , your_password , your_project )

		project.number <- values$proj_id
		
		# re-access the download-datasets page
		z <- httr::POST( "https://dhsprogram.com/data/dataset_admin/download-datasets.cfm" , body = list( proj_id = project.number ) )

		for ( i in seq_len( nrow( catalog ) ) ){

			# create a website key pointing the specific country
			values <- 
				list( 
					proj_id = catalog[ i , "proj_id" ] , 
					Apr_Ctry_list_id = catalog[ i , "Apr_Ctry_list_id" ] ,
					submitted = 2 ,
					action = "View Surveys" ,
					submit = "View Surveys"
				)

			# re-access the download data page
			# using the new country-specific key
			z <- httr::POST( "https://dhsprogram.com/data/dataset_admin/download-datasets.cfm" , body = values )
		
			# download the actual microdata file directly to disk
			# don't read it into memory.  save it as `tf` immediately (RAM-free)
			cachaca( catalog[ i , 'full_url' ] , destfile = catalog[ i , 'output_filename' ] , FUN = httr::GET , filesize_fun = 'unzip_verify' , httr::write_disk( catalog[ i , 'output_filename' ] , overwrite = TRUE ) , httr::progress() )
			
			# make sure the file-specific folder exists
			# dir.create( gsub( "\\.zip" , "" , zfn ) , showWarnings = FALSE )
			
			# unzip the contents of the zipped file
			unzipped_files <- unzip_warn_fail( catalog[ i , 'output_filename' ] , exdir = catalog[ i , 'output_folder' ] )

			# figure out the correct location for the rds
			rds_name <- gsub( "\\.zip" , ".rds" , catalog[ i , 'output_filename' ] )
			
			# and now, if there's a stata file, import it!
			if ( any( st <- grepl( "\\.dta$" , tolower( unzipped_files ) ) ) ){
				
				# remove any prior `x` tables ; clear up RAM
				suppressWarnings( rm( x ) )
				
				# load the current stata file into working memory
				x <- data.frame( haven::read_dta( unzipped_files[ which( st ) ] ) )
			
				# convert all column names to lowercase
				names( x ) <- tolower( names( x ) )

				catalog[ i , 'case_count' ] <- nrow( x )
				
				# save the file on the local disk, within the appropriate country-survey filepath
				saveRDS( x , file = rds_name ) ; rm( x ) ; gc()
				
			}

			# if a file has not been saved as an rds yet,
			# look for an spss file as well.  this way, stata always takes priority.
			if ( !file.exists( rds_name ) ){
			
				# if there's any spss file, import it!
				if ( any( st <- grepl( "\\.sav$" , tolower( unzipped_files ) ) ) ){
					
					# remove any prior `x` tables ; clear up RAM
					suppressWarnings( rm( x ) )
					
					# load the current stata file into working memory
					x <- data.frame( haven::read_spss( unzipped_files[ which( st ) ] ) )
		
					# convert all column names to lowercase
					names( x ) <- tolower( names( x ) )
					
					catalog[ i , 'case_count' ] <- nrow( x )

					# save the file on the local disk, within the appropriate country-survey filepath
					saveRDS( x , file = rds_name ) ; rm( x ) ; gc()
					
				}
			}
		
			# delete the temporary files
			suppressWarnings( file.remove( unzipped_files ) )

			cat( paste0( "\n\n" , data_name , " catalog entry " , i , " of " , nrow( catalog ) , " stored at '" , catalog[ i , 'output_filename' ] , "'\r\n\n" ) )

		}

		catalog

	}
	
	


dhs_authenticate <-
	function( your_email , your_password , your_project ){

		# authentication page
		terms <- "https://dhsprogram.com/data/dataset_admin/login_main.cfm"

		# countries page
		countries.page <- "https://dhsprogram.com/data/dataset_admin/download-datasets.cfm"

		# create a temporary file and temporary directory
		tf <- tempfile()


		# set the username and password
		values <- 
			list( 
				UserName = your_email , 
				UserPass = your_password ,
				Submitted = 1 ,
				UserType = 2
			)

		# log in.
		httr::GET( terms , query = values )
		httr::POST( terms , body = values )

		# extract the available countries from the projects page
		z <- httr::GET( countries.page )

		# write the information from the `projects` page to a local file
		writeBin( z$content , tf )

		# load the text 
		y <- readLines( tf , warn = FALSE )

		# figure out the project number
		project.line <- unique( y[ grep( paste0( "option value(.*)" , your_project ) , y ) ] )

		# confirm only one project
		stopifnot( length( project.line ) == 1 ) 

		# extract the project number from the line above
		project.number <- gsub( "(.*)<option value=\"([0-9]*)\">(.*)" , "\\2" , project.line )

		# log in again, but specifically with the project number
		list( 
			UserName = your_email , 
			UserPass = your_password ,
			proj_id = project.number
		)
	
	}
	