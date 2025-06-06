if (!require("pacman")) install.packages("pacman")
pacman::p_load(ggplot2, lubridate, stringr, readxl, data.table, gdata, tidyverse, dplyr)

# call individual scripts 
###source("submission_1/data-code/1_Plan_Data.R")
###source("submission_1/data-code/2_Plan_Characteristics.R")
###source("submission_1/data-code/3_Service_Areas.R")
###source("submission_1/data-code/4_Penetration_Files.R")
###source("submission_1/data-code/5_Star_Ratings.R")
###source("submission_1/data-code/6_Risk_Rebates.R")
###source("submission_1/data-code/7_MA_Benchmark.R")
###source("submission_1/data-code/8_FFS_Costs.R")



# tidy data 
full.ma.data <- read_rds("data/output/full_ma_data.rds")
contract.service.area <- read_rds("data/output/contract_service_area.rds")
star.ratings <- read_rds("data/output/star_ratings.rds")
ma.penetration.data <- read_rds("data/output/ma_penetration.rds")
plan.premiums <- read_rds("data/output/plan_premiums.rds")
risk.rebate.final <- read_rds("data/output/risk_rebate.rds")
benchmark.final <- read_rds("data/output/ma_benchmark.rds") %>%
  mutate(ssa=as.double(ssa))
ffs.costs.final <- read_rds("data/output/ffs_costs.rds")


final.data <- full.ma.data %>%
  inner_join(contract.service.area %>% 
               select(contractid, fips, year), 
             by=c("contractid", "fips", "year")) %>%
  filter(!state %in% c("VI","PR","MP","GU","AS","") &
           snp == "No" &
           (planid < 800 | planid >= 900) &
           !is.na(planid) & !is.na(fips))

final.data <- final.data %>%
  left_join( star.ratings %>%
               select(-contract_name, -org_type, -org_marketing), 
             by=c("contractid", "year")) %>%
  left_join( ma.penetration.data %>% ungroup() %>% select(-ssa) %>%
               dplyr::rename(state_long=state, county_long=county), 
             by=c("fips", "year"))


# calculate star rating (Part C rating if plan doesn't offer part D, otherwise Part D rating if available)
final.data <- final.data %>% ungroup() %>%
  mutate(Star_Rating = 
           case_when(
             partd == "No" ~ partc_score,
             partd == "Yes" & is.na(partcd_score) ~ partc_score,
             partd == "Yes" & !is.na(partcd_score) ~ partcd_score,
             TRUE ~ NA_real_
           ))

  final.state <- final.data %>% 
  group_by(state) %>% 
  summarize(state_name = tail(na.omit(state_long), 1)) ### I CHANGED THIS 

final.data <- final.data %>%
  left_join(final.state,
            by=c("state"))

final.data <- final.data %>%
  left_join( plan.premiums,
             by=c("contractid","planid","state_name"="state","county","year")) %>%
  left_join( risk.rebate.final %>%
               select(-contract_name, -plan_type),
             by=c("contractid","planid","year")) %>%
  left_join( benchmark.final,
             by=c("ssa","year"))


# calculate relevant benchmark rate based on star rating
final.data <- final.data %>% ungroup() %>%
  mutate(ma_rate =
           case_when(
             year<2012 ~ risk_ab,
             year>=2012 & year<2015 & Star_Rating == 5 ~ risk_star5,
             year>=2012 & year<2015 & Star_Rating == 4.5 ~ risk_star45,
             year>=2012 & year<2015 & Star_Rating == 4 ~ risk_star4,
             year>=2012 & year<2015 & Star_Rating == 3.5 ~ risk_star35,
             year>=2012 & year<2015 & Star_Rating == 3 ~ risk_star3,
             year>=2012 & year<2015 & Star_Rating < 3 ~ risk_star25,
             year>=2012 & year<2015 & is.na(Star_Rating) ~ risk_star35,
             year>=2015 & Star_Rating >= 4 ~ risk_bonus5,
             year>=2015 & Star_Rating < 4 ~ risk_bonus0,
             year>=2015 & is.na(Star_Rating) ~ risk_bonus35,
             TRUE ~ NA_real_
           ))

# final premium and bid variables
final.data <- final.data %>%
  mutate(basic_premium=
           case_when(
             rebate_partc>0 ~ 0,
             partd == "No" & !is.na(premium) & is.na(premium_partc) ~ premium,
             TRUE ~ premium_partc
           ),
         bid=
           case_when(
             rebate_partc == 0 & basic_premium > 0 ~ (payment_partc + basic_premium)/riskscore_partc,
             rebate_partc > 0 | basic_premium == 0 ~ payment_partc/riskscore_partc,
             TRUE ~ NA_real_
           ))

# incorporate ffs cost data by ssa
final.data <- final.data %>%
  left_join( ffs.costs.final %>%
               select(-state), 
             by=c("ssa","year")) %>%
  mutate(avg_ffscost = case_when(
    parta_enroll==0 & partb_enroll==0 ~ 0,
    parta_enroll==0 & partb_enroll>0 ~ partb_reimb/partb_enroll,
    parta_enroll>0 & partb_enroll==0 ~ parta_reimb/parta_enroll,
    parta_enroll>0 & partb_enroll>0 ~ (parta_reimb/parta_enroll) + (partb_reimb/partb_enroll),
    TRUE ~ NA_real_
  ))

# save final dataset
write_rds(final.data,"data/output/final_ma_data.rds")