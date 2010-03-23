############################################################
#                        projFuns.r                        #
# ---------------------------------------------------------#
# This file contains functions for project management GUI  #
# creation.                                                #
#                                                          #
# Authors:                                                 #
#  Jon T. Schnute <SchnuteJ@pac.dfo-mpo.gc.ca>,            #
#  Anisa Egeli <Anisa.Egeli@dfo-mpo.gc.ca>, and            #
#  Rowan Haigh <HaighR@pac.dfo-mpo.gc.ca>                  #
#                                                          #
############################################################

# ***********************************************************
# openPackageFile:
#  Open a file from a given package. This can be used via a
#  window description file using openPackageFile as the
#  function and packageName,relativeFilepath as the
#  action. Alternatively, it can be called without a GUI, in
#  which case the package and filepath are provided as
#  parameters.
# Input:
#  package - name of package in which to find file
#  filepath - filepath of file, relative from package root
# -----------------------------------------------------------
openPackageFile=function(package, filepath){
	warning( "this function is deprecated - use openFile" )
  if(missing(package) && missing(filepath)){
    action=strsplit(getWinAct()[1], ",")
    package=action[[1]][1]
    filepath=action[[1]][2]
  }
  openFile( filepath, package=package )
}

# ***********************************************************
# openProjFiles:
#  Open one or more files in the working directory, given one
#  file prefix and one or more file suffixes.
#  A suffix may contain wild card characters (? and *)--
#  if more than one file is found matching a single suffix
#  in this way then only the first is opened.
#  This function can also be used to automatically copy and
#  open a template associated with each given suffix if the
#  file does not already exist in the working directory
#  The template should be found in the template subdirectory
#  for the given package. No error will occur if the template
#  option is used and there is no template to copy.
#  The action in the window description file should follow
#  the format packageName,suffix1,suffix2,suffixN
#  If the package name is omitted, ie. ,suffix1,suffix2
#  then no templates will be copied
#  If an editor option has been set, the files will be
#  opened using this, otherwise openFile will be used.
# Input:
#  prefix - prefix of file
#  suffix - character vector of suffixes
#  package - name of package to find template or NULL to not use
#            templates
#  warn - NULL to not change warn setting, or a value to change
#         the R warn option to temporarily
#  alert - If TRUE, a pop-up alert message is shown if
#          a file failed to be opened.
# Output:
#   Returns FALSE if a one or more of the files failed to be
#   opened, TRUE otherwise
# -----------------------------------------------------------
openProjFiles=function(prefix, suffix, package=NULL, warn=NULL, alert=TRUE){
	oldWarn=options("warn")[[1]]
	if(!is.null(warn))
		options("warn"=warn)
		
	if(missing(prefix) && missing(suffix)){
    prefix=.getPrefix(quiet=!alert)
    if (is.null(prefix)){
			warning("Must specify prefix.")
			options("warn"=oldWarn)
      return(FALSE)
		}
    action=strsplit(getWinAct()[1], ",")[[1]]
    package=action[1]
    suffix=action[2:length(action)]
	} else if (missing(prefix)){
		warning('argument "prefix" is missing, with no default')
		options("warn"=oldWarn)
  	return(FALSE)
	} else if (missing(suffix)){
		warning('argument "suffix" is missing, with no default')
		options("warn"=oldWarn)
  	return(FALSE)
 	}
		
  notOpened=character(0)
  for(sufI in suffix){
    localFilename=Sys.glob(paste(prefix, sufI, sep=""))
    if(length(localFilename))
      localFilename=localFilename[1]
    else if(!is.null(package)){
      template=Sys.glob(paste(system.file("templates", package=package), "/",
          prefix, sufI, sep=""))
      if(length(template)){
        expandedSuf=sub("*template", "", template[1])
        localFilename=paste(prefix, suffix, sep="")
        file.copy(from=template[1], to=localFilename)
      }
    }
    if(!.tryOpen(localFilename, quiet=TRUE))
      notOpened=c(notOpened, localFilename)
  }
  options("warn"=oldWarn)
  if(alert && length(notOpened))
		showAlert(paste("Could not open", paste(notOpened, collapse=", ")))
  return(!as.logical(length(notOpened)))
}

# ***********************************************************
# openExamples: Open examples from the examples subdirectory
#  of a given package, making copies into the working
#  directory. If files with the same name already exist than
#  the user is prompted with the choice to overwrite.
# Input:
#  package - package that contains the examples
#            (in example subdir)
#  prefix - prefix of example files
#  suffix - suffixes of example files (character vector)
# -----------------------------------------------------------
openExamples=function(package, prefix, suffix){
  if(missing(package) && missing(prefix) && missing(suffix)){
    fromGUI=TRUE
    action=strsplit(getWinAct()[1], ",")[[1]]
    package=action[1]
    prefix=action[2]
    suffix=action[3:length(action)]
  } else
    fromGUI=FALSE

  filepaths=Sys.glob(paste(system.file("examples", package=package), "/",
      prefix, suffix, sep=""))
  filenames=basename(filepaths)

  for(i in 1:length(filenames)){
    if(!file.exists(filenames[i]) || getYes(paste("Overwrite existing ",
        filenames[i], "?", sep="")))
      file.copy(from=filepaths[i], to=filenames[i], overwrite=TRUE)
  }

  if(fromGUI)
    try(setWinVal(list("prefix"=prefix)), silent=TRUE)

  for(i in filenames)
    .tryOpen(i)
}

# ***********************************************************
# setPathOption:
#  Set a PBS option by browsing for a directory.
#  If this is used in a Window description file, the widget
#  action will be used for the option name. If a window
#  containing a widget with the same name as the option is
#  open, the widget value will be set to the new value.
# Input:
#  option - name of the option to change
# Output:
#   Returns TRUE if the option was set, FALSE if the
#   prompt was cancelled
# -----------------------------------------------------------
setPathOption=function(option){
  .setOption(option, "dir")
}

# ***********************************************************
# setFileOption:
#  Set a PBS option by browsing for a file.
#  If this is used in a Window description file, the widget
#  action will be used for the option name. If a window
#  containing a widget with the same name as the option is
#  open, the widget value will be set to the new value.
# Input:
#  option - name of the option to change
# Output:
#   Returns TRUE if the option was set, FALSE if the
#   prompt was cancelled
# -----------------------------------------------------------
setFileOption=function(option){
  .setOption(option, "file")
}

# ***********************************************************
# findPrefix:
# Input:
#  suffix - character vector of suffixes to match to a file.
# Output: character vector of files with matching extensions
# -----------------------------------------------------------

findPrefix=function(suffix, path = "." ) {
	if( length( suffix ) > 1 ) {
		ret <- c()
		for( s in suffix )
			ret <- c( ret, findPrefix( s, path ) )
		return( ret )
	}
	#spat=gsub("\\.","\\\\\\.",suffix)                    # wrong: produces three backslashes
	#spat=gsub("\\.",paste("\\\\","\\.",sep=""),suffix)   # possibly correct but unnecessary
	spat=gsub("\\.","\\\\.",suffix)                       # sufficient
	sfiles=list.files( path, pattern=paste(spat,"$",sep=""),ignore.case=TRUE)
	pref=substring(sfiles,1,nchar(sfiles)-nchar(suffix))
	return(pref)
}

findSuffix=function( prefix, path = "." ) {
	if( length( prefix ) > 1 ) {
		ret <- c()
		for( p in prefix )
			ret <- c( ret, findSuffix( p, path ) )
		return( ret )
	}
	#spat=gsub("\\.","\\\\\\.",suffix)                    # wrong: produces three backslashes
	#spat=gsub("\\.",paste("\\\\","\\.",sep=""),suffix)   # possibly correct but unnecessary
	spat=gsub("\\.","\\\\.",suffix)                       # sufficient
	sfiles=list.files(path,pattern=paste("^", spat,sep=""),ignore.case=TRUE)
	pref=substring(sfiles,nchar(prefix) + 1)
	return(pref)
}

#One big hack to allow GUIs from outside PBSmodelling to call PBSmodelling's internal hidden functions.
#Do not rely on this to remain here - functions beginning with a '.' should ONLY be called from PBSmodelling.
#TODO REMOVE THIS - after PBSadmb is refactored
.getHiddenEnv <- function()
{
	return( environment() )
}


# ***********************************************************
# setwdGUI:
#  change the working directory via a GUI
# -----------------------------------------------------------
setwdGUI=function(){
  wd=as.character(tkchooseDirectory())
  if(!length(wd))
    return()
  setwd(wd)
}

# ***********************************************************
# promptWriteOptions
#  Prompts user to save options if a change was made since
#  last load
# Input:
#  fname: name of file in which the options will be saved
# -----------------------------------------------------------
promptWriteOptions=function(fname=""){
  .initPBSoptions()

  if(.optionsNotUpdated() && getYes("Set declared options to widget values?"))
  	setGUIoptions("*")

#doesn't save if nothing's changed but we changed the fname - or if we modify .PBSmod directly	
#  if(!is.null(.PBSmod$.options$.optionsChanged) ){
    if(fname=="" && !is.null(.PBSmod$.options$.optionsFile)){
      if (getYes(paste("Save settings to", .PBSmod$.options$.optionsFile, "?")))
        writePBSoptions(.PBSmod$.options$.optionsFile)
    }
    if(fname=="")
			fname="PBSoptions.txt"
    if (getYes(paste("Save settings to", fname, "in working directory?")))
      writePBSoptions(fname)
#  }
}

#declareGUIoptions----------------------2009-03-03
#  Used to add options that a GUI uses/loads. The widget
#  names in the window description file should match.
# Input:
#  newOptions - a character vector of option names
#--------------------------------------------AE/RH
declareGUIoptions=function(newOptions){
  .initPBSoptions()
  #.PBSmod$.options$.optionsDeclared<<-.mergeVectors(.PBSmod$.optionsDeclared,newOptions)
  .optionsDeclared=.mergeVectors(.PBSmod$.optionsDeclared,newOptions)
  packList(".optionsDeclared",".PBSmod$.options")
}

# ***********************************************************
# getGUIoptions:
#  Set used option values as specified by declareGUIoptions in
#  GUI from stored values, possibly trying to load new values
#  from a saved options file
#  It is assumed .PBSmod is initialized
# -----------------------------------------------------------
getGUIoptions=function(){
	for(i in .PBSmod$.options$.optionsDeclared){
		option=list()
		option[[i]]=.PBSmod$.options[[i]]
		try(setWinVal(option), silent=TRUE)
	}
}

# ***********************************************************
# setGUIoptions
#  Transfer option from GUI to option stored in memory.
#  If no option is specified, the option to update is
#  indicated by the last GUI action.
#  "*" updates all options, as given by declareGUIoptions.
# Input:
#  option - name of option to update or "*" to update all
# -----------------------------------------------------------
setGUIoptions=function(option){
  .initPBSoptions()
  if(missing(option))
    option=getWinAct()[1]
  if(option=="*"){
    option=names(getWinVal(.PBSmod$.options$.optionsDeclared))
  }

  for(i in option){
    setPBSoptions(i, getWinVal(i)[[i]])
  }
}


# ***********************************************************
# getYes:
#  A pop-up box prompting the user to choose Yes or No
# Input:
#  message - the message to display in the pop-up
#  title - the title of the pop-up
#  icon - icon to use in message box
# Output: TRUE if Yes was chosen or FALSE if No was chosen
# -----------------------------------------------------------
getYes=function(message, title="Choice", icon="question"){
  answer=as.character(tkmessageBox(message=message, title=title,
			icon=icon, type="yesno"))

  if(answer=="yes")
    return(TRUE)

  return(FALSE)
}

# ***********************************************************
# showAlert:
#  Show an alert pop-up box with a message.
# Input:
#  message - the message to display in the alert
#  title - the title of the alert box
#  icon - icon to show in alert box
# -----------------------------------------------------------
showAlert=function(message, title="Alert", icon="warning"){
  tkmessageBox(message=message, title=title, icon=icon)
}

# ***********************************************************
# .showLog:
#  Given output for a log, will make pop-up log window
#  containing this output and/or write this output to a
#  logfile. \r is stripped from the log text for display
# Input:
#  logText - the text for the log
#  fname (optional) - name for log file
#  noWindow - if TRUE, log window will not be shown
#  width - width of log window
#  height - height of log window
# -----------------------------------------------------------
.showLog=function(logText, fname, noWindow=FALSE, width=80, height=30){
  if(!noWindow){
    winDesc=c(
        "window name=PBSlog title=LOG",
        paste("text name=logText width=", width, " height=", height,
        " edit=FALSE scrollbar=TRUE mode=character", sep=""))
    createWin(winDesc, astext=TRUE)
    setWinVal(list("logText"=gsub("\r", "", logText)), winName="PBSlog")
  }
  if(!missing(fname)){
    cat(logText, file=fname)
  }
}

# ***********************************************************
# .stripExt:
#  remove file extension from end of filename
# Input:
#  x - character vector of filenames, ie. "foo.c"
# Output: the filename without the extension, ie. "foo"
# -----------------------------------------------------------
.stripExt=function(x){
	return(sub("[.].{1,3}$", "", x))
}

# ***********************************************************
# .removeFromList:
#  Remove components of a list with the given names. "NA" can
#  be used to remove NA names
# Input:
#  l - a list
#  items - character vector of names of components to remove
# Output:
#  a list with the chosen components removed
# -----------------------------------------------------------
.removeFromList=function(l, items){
  if(!length(l) || !length(items))
    return(l)

  indices=integer()
  for(i in 1:length(l)){
    nameI=names(l[i])
    if(is.na(nameI))
      nameI="NA"
    if(any(items==nameI)){
      indices=c(indices, i)
    }
  }
  if(length(indices))
    return(l[-indices])
  return(l)
}

# ***********************************************************
# .mergeLists:
#  Add a second list to a first list. If both lists share any
#  keys, the values from the second list overwrite those in
#  the first list. Order of components in list is preserved.
# Input:
#  list1 - first list
#  list2 - second list
# Output:
#   the two lists merged as described above
# -----------------------------------------------------------
.mergeLists=function(list1, list2){
  if(!length(list1))
    return(list2)
  if(!length(list2))
    return(list1)

  newComponents=list()

  for(i in 1:length(list2)){
    nameI=names(list2[i])
    if(any(names(list1)==nameI))
      list1[[nameI]]=list2[[nameI]]
    else
      newComponents[[nameI]]=list2[[nameI]]
  }

  return(c(list1, newComponents))
}

# ***********************************************************
# .mergeVectors:
#  Add a second vector to a first vector. If both vectors
#  share any values, the resulting vector will only contain
#  this value once
# Input:
#  v1 - first vector
#  v2 - second vector
# Output:
#   the two vectors merged as described above
# -----------------------------------------------------------
.mergeVectors=function(v1, v2){
  if(!length(v2))
    return(v1)

  newVals=vector()
  for(i in 1:length(v2)){
    if(!any(v1==v2[i]))
      newVals=c(newVals, v2[i])
  }
  return(c(v1, newVals))
}

# ***********************************************************
# .getPrefix:
#  get the project prefix from the focused GUI. Used to
#  standardize the error message.
# Input:
#  quiet - If TRUE, no errors/alerts will be displayed
# Output: the prefix, or NULL if the entry box was empty.
# -----------------------------------------------------------
.getPrefix=function(quiet=FALSE){
  getWinVal("prefix", scope="L")
  if (prefix==""){
    if(!quiet)
      showAlert("Please enter the prefix/name of your project.")
    return(NULL)
  }
  return(prefix)
}

# ***********************************************************
# .tryOpen:
#  Tries to open a given file using an editor entered by the
#  GUI. If an editor wasn't set, tries to open using openFile.
#  Appropriate alerts are shown if quiet isn't turned on.
# Input:
#  filename - the file to open
#  quiet - if quiet is TRUE, alerts will not be shown
# Output:
#   returns TRUE if file exists and a program to open the
#   file was specified somewhere, FALSE otherwise.
# -----------------------------------------------------------
.tryOpen=function(filename, quiet=FALSE){
  filename=filename[1]
  if(!is.character(filename) || !file.exists(filename)){
    if(!quiet)
      showAlert(paste("File", filename, "does not exist."))
    return(FALSE)
  }
  .initPBSoptions()
  if(!is.null(.PBSmod$.options$editor) && file.exists(.PBSmod$.options$editor)){
    cmd=paste(shQuote(.PBSmod$.options$editor), filename)
    system(cmd, wait=FALSE, invisible=FALSE)
  }else{
    tryRet=try(openFile(filename), silent=TRUE)
    if(class(tryRet)=="try-error"){
      if(!quiet)
        showAlert(paste("Could not open file ", filename, ". Please choose ",
            "a default editor or set the appropriate file association.",
            sep=""))
      return(FALSE)
    }
  }
  return(TRUE)
}

# ***********************************************************
# .optionsNotUpdated
#  Check if any of the options given by declareGUIoptions are
#  different in the GUI from their stored values. A blank
#  GUI entry is equivalent to the option not being set.
# Ouput:
#  Returns TRUE if any of the options are different in the
#  GUI than in their stored values
# -----------------------------------------------------------
.optionsNotUpdated=function(){
  .initPBSoptions()
  if(is.null(.PBSmod$.options$.optionsDeclared))
		return(FALSE)
		
  winVals=try(getWinVal(.PBSmod$.options$.optionsDeclared), silent=TRUE)
  if(class(winVals)=="try-error")
		return(FALSE)

  for(i in names(winVals)){
    if((is.null(.PBSmod$.options[[i]]) && winVals[[i]]!="") ||
        (!is.null(.PBSmod$.options[[i]]) &&
        winVals[[i]]!=.PBSmod$.options[[i]]))
       return(TRUE)
  }
  return(FALSE)
}

# ***********************************************************
# .getHome:
#  Returns platform dependent home drive (Windows) or user
#  home (Unix) -- NOT TESTED ON UNIX.
# Output:
#  HOMEDRIVE or HOME environment variable for Windows or Unix
#  respectively
# -----------------------------------------------------------
.getHome=function(){
  if (.Platform$OS.type=="windows")
    return(Sys.getenv("HOMEDRIVE")[[1]])
   return(Sys.getenv("HOME")[[1]])
}

#.setOption-----------------------------2008-08-25
# This used used for setPathOption and setFileOption-- see these functions for
# a description. The type is "dir" or "file" for each of those functions.
#-----------------------------------------------AE
.setOption=function(option, type){
  if(missing(option))
    option=getWinAct()[1]

  .initPBSoptions()
  if(!is.null(.PBSmod$.options[[option]]) &&
      file.exists(.PBSmod$.options[[option]]))
    initDir=.PBSmod$.options[[option]]
  else
    initDir=.getHome()

  if(type=="dir")
    value=paste(as.character(tkchooseDirectory(initialdir=initDir)),
        collapse=" ")
  else
    value=paste(as.character(tkgetOpenFile(initialdir=initDir)), collapse=" ")

  if(nchar(value)){
    newVal=list()
    newVal[[option]]=value
    try(setWinVal(newVal), silent=TRUE)
    setPBSoptions(option, value)
    return(TRUE)
  }
  return(FALSE)
}

#.selectCleanBoxes----------------------2008-08-25
# This is used by cleanProj. It is the function for selecting or deselecting
# all of the checkboxes.
#-----------------------------------------------AE
.selectCleanBoxes=function(){
	action=getWinAct()[1]
	vecList=.removeFromList(getWinVal(), "cleanPrefix")
	for(i in 1:length(vecList)){
		vecList[[i]]=rep(action, length(vecList[[i]]))
	}
	setWinVal(vecList)
}

#.makeCleanVec--------------------------2009-03-03
# This is used by cleanProj() to create the strings describing checkbox vectors.
#--------------------------------------------AE/RH
.makeCleanVec=function(vecName, items, rowLen){
	vecDesc=character(0)
	nItems=length(items)
	nVecs=ceiling(nItems/rowLen)
	if(!nVecs)
		return(vecDesc)
	for(i in 1:nVecs){
		vecI=paste("vector names=", vecName, i, " ", sep="")
		currItems=items[((i-1)*rowLen+1):min(rowLen*i, nItems)]
		itemStr=paste("\'",paste(currItems, collapse="\' \'"),"\'",sep="")
		vecI=paste(vecI, 'vecnames="', itemStr, '" ', sep="")
		vecI=paste(vecI, 'labels="', itemStr, '"', sep="")
		vecI=paste(vecI, " length=", length(currItems), sep="")
		vecI=paste(vecI," mode=logical vertical=FALSE value=TRUE padx=4 pady=4")
		vecDesc=c(vecDesc, vecI)
	}
	return(vecDesc)
}

