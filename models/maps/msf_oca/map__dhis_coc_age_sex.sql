-- DHIS2 category-option-combos for the age x sex disaggregation (MSF OCA
-- category combo CjVsc7apGqi): 5 age groups x 3 sex. Shared across MSF OCA
-- deployments -- the UIDs are global to the MSF OCA DHIS2 instance. Built only
-- when var('msf_oca_dhis2') is true. Joined on (age_group, sex).
select * from (
    values
        ('CHskMNYmgS7', '<5 years', 'Female'),
        ('M4tYlxBXbAv', '<5 years', 'Male'),
        ('OrfBbRS529C', '<5 years', 'Other/Unknown'),
        ('CAf7HoJlT0e', '5-14 years', 'Female'),
        ('HLt8zY0ApNP', '5-14 years', 'Male'),
        ('sTsM0GLteNy', '5-14 years', 'Other/Unknown'),
        ('ilVdY5KySSE', '15-49 years', 'Female'),
        ('kTsGgP1syhU', '15-49 years', 'Male'),
        ('dCg2P4t2TaS', '15-49 years', 'Other/Unknown'),
        ('OQQp1Q2Yqei', '50+ years', 'Female'),
        ('dl3RdOuje7E', '50+ years', 'Male'),
        ('ovDRzDjquI1', '50+ years', 'Other/Unknown'),
        ('A1JlPLUhDvy', 'Unknown age', 'Female'),
        ('aAeqKcxxy7m', 'Unknown age', 'Male'),
        ('eNQsGiCb9Y1', 'Unknown age', 'Other/Unknown')
) as t(id, age_group, sex)
