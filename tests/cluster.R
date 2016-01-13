library("future")
library("listenv")

ovars <- ls()
oopts <- options(warn=1L, mc.cores=2L)

for (cores in 1:min(3L, availableCores())) {
  message(sprintf("Testing with %d cores ...", cores))
  options(mc.cores=cores-1L)

  cl <- parallel::makeCluster(cores)
  plan(cluster, cluster=cl)

  message("*** cluster() ...")

  ## No global variables
  f <- cluster({
    42L
  }, cluster=cl)
  print(f)
  stopifnot(inherits(f, "ClusterFuture"))

  print(resolved(f))
  y <- value(f)
  print(y)
  stopifnot(y == 42L)


  ## A global variable
  a <- 0
  f <- future({
    b <- 3
    c <- 2
    a * b * c
  })
  print(f)


  ## A cluster future is evaluated in a separate
  ## R session process.  Changing the value of a global
  ## variable should not affect the result of the
  ## future.
  a <- 7  ## Make sure globals are frozen
  if ("covr" %in% loadedNamespaces()) v <- 0 else ## WORKAROUND
  v <- value(f)
  print(v)
  stopifnot(v == 0)


  message("*** cluster() with globals and blocking")
  x <- listenv()
  for (ii in 1:4) {
    message(sprintf(" - Creating cluster future #%d ...", ii))
    x[[ii]] <- future({ ii })
  }
  message(sprintf(" - Resolving %d cluster futures", length(x)))
  v <- sapply(x, FUN=value)
  stopifnot(all(v == 1:4))


  message("*** cluster() and errors")
  f <- future({
    stop("Whoops!")
    1
  })
  print(f)
  v <- value(f, onError="return")
  print(v)
  stopifnot(inherits(v, "simpleError"))

  res <- try(value(f), silent=TRUE)
  print(res)
  stopifnot(inherits(res, "try-error"))

  ## Error is repeated
  res <- try(value(f), silent=TRUE)
  print(res)
  stopifnot(inherits(res, "try-error"))


  message("*** cluster() - too large globals ...")
  ooptsT <- options("future.maxSizeOfGlobals"=1024*4L)

  limit <- getOption("future.maxSizeOfGlobals")
  cat(sprintf("Max total size of globals: %g bytes\n", limit))

  ## A large object
  a <- 1:1014
  yTruth <- sum(a)
  size <- object.size(a)
  cat(sprintf("a: %g bytes\n", size))
  f <- future({ sum(a) })
  print(f)
  rm(list="a")
  v <- value(f)
  print(v)
  stopifnot(v == yTruth)


  ## A too large object
  a <- 1:1019 ## also on 32-bit platforms
  yTruth <- sum(a)
  size <- object.size(a)
  cat(sprintf("a: %g bytes\n", size))
  res <- try(f <- future({ sum(a) }), silent=TRUE)
  rm(list="a")
  stopifnot(inherits(res, "try-error"))

  ## Undo options changed in this test
  options(ooptsT)

  message("*** cluster() - too large globals ... DONE")

  message(sprintf("Testing with %d cores ... DONE", cores))
} ## for (cores ...)

message("*** cluster() ... DONE")


## Cleanup
parallel::stopCluster(cl)
plan(eager)
options(oopts)
rm(list=setdiff(ls(), ovars))