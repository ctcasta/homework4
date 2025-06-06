monthlist_2010=c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")
monthlist_2011=c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")
monthlist_2012=c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")
monthlist_2013=c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")
monthlist_2014=c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")
monthlist_2015=c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")


## read in monthly files, append to yearly file, fill in missing info, and collapse down to yearly file
for (y in 2010:2015) {
  monthlist=get(paste0("monthlist_",y))
  step=0
  for (m in monthlist) {
    step=step+1
    
    ## Pull service area data by contract/month
    ma.path=paste0("data/input/monthly-ma-contract-service-area/MA_Cnty_SA_",y,"_",m,".csv")
    service.area=read_csv(ma.path,skip=1,
                          col_names=c("contractid","org_name","org_type","plan_type","partial","eghp",
                                      "ssa","fips","county","state","notes"),
                          col_types = cols(
                            contractid = col_character(),
                            org_name = col_character(),
                            org_type = col_character(),
                            plan_type = col_character(),
                            partial = col_logical(),
                            eghp = col_character(),
                            ssa = col_double(),
                            fips = col_double(),
                            county = col_character(),
                            notes = col_character()
                          ), na='*')
    service.area = service.area %>%
      mutate(month=m, year=y)
    if (step==1) {
      service.year=service.area
    } else {
      service.year=rbind(service.year,service.area)
    }
  }
  
  
  ## Fill in missing fips codes (by state and county)
  service.year = service.year %>%
    group_by(state, county) %>%
    fill(fips)

  ## Fill in missing plan type, org info, partial status, and eghp status (by contractid)
  service.year = service.year %>%
    group_by(contractid) %>%
    fill(plan_type, partial, eghp, org_type, org_name)
  

  ## Collapse to yearly data
  service.year = service.year %>%
    group_by(contractid, fips) %>%
    mutate(id_count=row_number())
  
  service.year = service.year %>%
    filter(id_count==1) %>%
    select(-c(id_count,month))

  
  assign(paste("service.area.",y,sep=""),service.year)  
}

contract.service.area=rbind(service.area.2010,service.area.2011,service.area.2012,
                            service.area.2013,service.area.2014,service.area.2015)


write_rds(contract.service.area, "data/output/contract_service_area.rds")