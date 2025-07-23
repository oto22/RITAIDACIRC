## dataset for RITA ##
rm(list=ls()) #remove all clean workspace memory
## load packages
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg))
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}
# usage
packages <- c("installr", "RPostgreSQL", "dplyr","lubridate",
              "ggplot2","tidyr","openxlsx",
              "readxl","readr")
ipak(packages)


### set wirking directory
workwd <- "D:/OTO/Data_Qdb" #/2018_respond/code/RforRespond"
homewd <- "D:/OTO/Data_Qdb" #code/RforRespond
if(isTRUE(file.info(workwd) [1,"isdir"])){
  setwd(workwd);dir() # dir.create is used to creatge not existing directory
}else{
  (isTRUE(file.info(homewd)[1,"isdir"]))
  setwd(homewd);dir()
}
getwd()

### import from postgreslq
source("./Connect_to_PGSQL.R") # load data from postgresql, you should enter database name

# ### import from postgreslq
# con <- dbConnect(RPostgres::Postgres(),
#                  dbname = "aidshis09052025",
#                  # host = localhost,
#                  port = 5432,
#                  user = "postgres",
#                  password = "ototata"
# )
### VL CD4 data ###
labdt <- dball %>%
  filter(vid == 157) %>%  
  mutate(lvd = year(labdate)) %>%
  arrange(labdate, rslt) %>%
  group_by(id) %>%
  summarise(cd4frst = first(rslt), cd4frdtt = min(labdate)) %>%
  arrange(id);
glimpse(labdt)

rita <- patient %>% 
  inner_join(labdt, by = c("regnum" = "id")) %>%
  filter(regdate > '2024-01-01', regdate < '2024-12-31', !is.na(regnum)) %>%
  mutate(dob = ymd(birthdate),
         gender = ifelse(genderid == 4, "M", "F"),
         trmode   = recode(transferid, '47' = "IDU", 
                          '48' = "HETERO", 
                          '49' = "HOMO",
                          '50' = "HEMOTR", 
                          '51' = "PMTCTC",
                          '52' = "UNKN", .default = "999"),
         age = as.duration(interval(dob, '2024-12-31')) %/% as.duration(years(1))) %>%
  select(regnum, fname, lname, regdate, dob, age, gender, trmode, deathdate, cd4frst, cd4frdtt, centerid)
glimpse(rita)

## ill data
illlists <- dbill %>% 
  inner_join(listill, by = c("illid"), suffix = c("_illpatnt", "_illlist"))

names(illlists)

###
ritqdb <-  rita %>% 
  left_join(illlists, by = c("regnum")) %>% 
  mutate(illdf = as.duration(interval(regdate, diagnosisdate)) %/% as.duration(months(1)),
         illfltr = ifelse(illdf < 6 & (illid %in% c(585, 583, 580 )), "dell", "kp")) %>% 
  filter(cd4frst >= 200, age > 18, 
         regdate > '2024-01-01', regdate < '2024-12-31', 
         illtypeid_illlist != 1 | is.na(illtypeid_illlist), 
         illfltr != "dell", centerid < 5) %>%
  select(regnum, fname, lname, regdate, dob, age, centerid) %>% 
  unique.data.frame() 

names(ritqdb)

### random selected data frame for 150 patients
ritqdbf <- ritqdb[sample(nrow(ritqdb), size = 150, replace = FALSE),]

## write data for RITA
write.csv(ritqdbf,  paste0(getwd(), "/outcomes/ritqdbf", 
                           Sys.Date(), ".csv", sep = ""), 
          row.names=F, na="")

write.xlsx(ritqdbf,  paste0(getwd(), "/outcomes/ritqdbf", 
                            Sys.Date(), ".xlsx", sep = ""))
