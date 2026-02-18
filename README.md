# GeoScan and Remote Geo Smoking Study: Neural and Behavioral Correlates of Smokers' Exposure to Retail Environments

For more information, visit the [study website](https://cnlab.github.io/geo-remote-website/).

---

## Table of Contents

1. [Background and Study Rationale](#background-and-study-rationale)
2. [Introduction](#introduction)
   - [Background and Relevant Literature](#background-and-relevant-literature)
3. [Study Objectives](#study-objectives)
   - [Primary Objective](#primary-objective)
4. [Investigational Plan](#investigational-plan)
   - [General Design](#general-design)
   - [Allocation to Interventional Group](#allocation-to-interventional-group)
   - [Study Measures](#study-measures)
   - [Study Endpoints](#study-endpoints)
5. [Study Population and Duration of Participation](#study-population-and-duration-of-participation)
   - [Duration of Study Participation](#duration-of-study-participation)
   - [Total Number of Subjects and Sites](#total-number-of-subjects-and-sites)
   - [Inclusion Criteria](#inclusion-criteria)
   - [Exclusion Criteria](#exclusion-criteria)
   - [Subject Recruitment](#subject-recruitment)
6. [Study Procedures](#study-procedures)
   - [Screening](#screening)
   - [Study Observational Phase](#study-observational-phase)
   - [Study Interventional Phase](#study-interventional-phase)
   - [Unscheduled Visits](#unscheduled-visits)
   - [Subject Withdrawal and Exclusion](#subject-withdrawal-and-exclusion)
   - [Early Termination Visits](#early-termination-visits)
   - [Safety Evaluation](#safety-evaluation)
7. [Statistical Plan](#statistical-plan)
   - [Sample Size and Power Determination](#sample-size-and-power-determination)
   - [Statistical Methods](#statistical-methods)
   - [Control of Bias and Confounding](#control-of-bias-and-confounding)
8. [Safety and Adverse Events](#safety-and-adverse-events)
9. [Study Administration, Data Handling and Record Keeping](#study-administration-data-handling-and-record-keeping)
10. [Study Monitoring, Auditing, and Inspecting](#study-monitoring-auditing-and-inspecting)
11. [Ethical Considerations](#ethical-considerations)
12. [Study Finances](#study-finances)
13. [Publication Plan](#publication-plan)
14. [References](#references)

---

## Study Summary

| Field | Details |
|---|---|
| **Title** | Remote Geo Smoking Study: Behavioral and Geospatial Correlates of Smokers' Exposure to Retail Environments |
| **Short Title** | Remote Geo |
| **IRB Number** | 850796 |
| **Methodology** | This study will utilize a randomized trial to examine the effects of point-of-sale tobacco marketing on smoking behaviors and brain activity. After a two week observational period, participants will be randomized to one of three behavioral intervention conditions for the duration of a four week intervention period. |
| **Study Duration** | Five years |
| **Study Center(s)** | Single-center |
| **Number of Subjects** | 343 [Actual] |
| **Intervention** | Random assignment of retail environment (high POSTM; low POSTM, control [no store]) to visit 5 times per week during the 4-week intervention period. |
| **Statistical Methodology** | Linear regression and multilevel models (in R); nipype, SPM, and fmriprep for fMRI data. |
| **Data and Safety Monitoring Plan** | The principal investigator will monitor the safety, privacy, and data integrity during the course of the study. Required project reports will be provided to the sponsor. |

**Objectives:**
- Understand the effects of point-of-sale tobacco marketing (POST-M) on smoking behavior and cravings in smokers. Examine whether experimental group assignment affects cigarette cravings and consumption during the intervention period relative to the baseline period.
- For a subset of participants, examine brain responses during the smoking cue reactivity task.

**Key Inclusion Criteria (remote):** Ages 21–65; smoke ≥5 cigarettes/day for past 6 months; smartphone owner; resident of PA, NJ, or DE; fluent English; fully vaccinated against COVID-19.

**Key Exclusion Criteria (remote):** Current/planned enrollment in a smoking cessation program; plans to use nicotine substitutes; urine cotinine below 200 ng/mL; pregnancy; inability or refusal to complete study tasks.

---

## Background and Study Rationale

This document is a protocol for a human research study. This study will be conducted in full accordance with all applicable University of Pennsylvania Research Policies and Procedures and all applicable Federal and state laws and regulations.

---

## Introduction

Cigarette smoking is the leading cause of preventable death and illness in the United States and throughout the developed world. Recent work suggests detrimental links between exposure to point-of-sale tobacco marketing (POSTM), increases in cigarette cravings, and the failure to quit smoking. Understanding how individuals are influenced by and react to environmental cues when making health decisions is critical to cancer control efforts and policymaking. We propose to use an innovative set of methods to test whether repeated, real-world exposure to POSTM affects smoking behavior, and whether this is mediated by changes in craving and neural responses to POSTM.

Our approach combines mobile-phone based geolocation tracking, ecological momentary assessment (EMA), and functional magnetic resonance imaging (fMRI). Research using geospatial location tracking and surveys suggests that high levels of POSTM exposure may increase craving; however, correlational studies preclude causal inferences about POSTM effects. Relatedly, laboratory studies have documented neural and behavioral reactivity to standardized visual smoking cues, such as photographs of cigarettes in an ashtray, but the brain's response to naturalistic POSTM exposure has not been explored. By adding the ecological validity of observational field methods to the mechanistic insight of neuroimaging, and causal inferences from an experimental pre-post design, we aim to significantly advance actionable insight about POSTM effects in cancer control.

### Background and Relevant Literature

**Summary:**

The tobacco industry has come to rely increasingly on point-of-sale tobacco marketing (POST-M), with large displays near cash registers in retail outlets such as convenience stores and gas stations [1]. Recent work utilizing geospatial location tracking has found that smoking lapses while smokers are trying to quit are more likely on days when smokers are exposed to POST-M, particularly when their general tobacco craving levels are otherwise low [2]. This suggests that POST-M exposure may increase craving, making abstinence more difficult. This finding converges with recent survey results demonstrating that during quit attempts, a significant percentage of smokers experience urges to purchase cigarettes when exposed to POST-M, and feel that the removal of POST-M would make quitting easier [3]. These reports indicating that incidental exposure to cigarette cues adversely affects smoking abstinence are supported by laboratory studies. A typical laboratory cue reactivity paradigm involves presenting participants with pictures or video of smoking cues, such as a hand holding a cigarette, followed by a measurement of participants' craving intensity. Smoking abstinence has been found to potentiate self-reported craving in response to cigarette cues [4-8], suggesting a mechanism for the finding that exposure to POST-M during a quit attempt leads to poorer outcomes. No studies, however, have experimentally manipulated exposure to POST-M cues in vivo.

To this end, we will examine whether assigning smokers to a high or low level of POST-M exposure as part of their daily routine affects several smoking outcomes. A location tracking smartphone application (Google Maps) will be used to document participants' exposure to retail outlets and link each person to the retail environment. Measurements will assess longitudinal tobacco-use patterns and perceptions across the study period, as well as changes in cravings. If it is the case that low POST-M exposure reduces smoking, this emphasizes the importance of further regulation of retail advertising for tobacco.

In addition to the hypotheses and analysis plans described here, the study team has preregistered additional hypotheses and analysis plans which are not the focus of the clinical trial component of the study. These are available at [https://osf.io/kyb64/registrations](https://osf.io/kyb64/registrations).

**Background:**

**Tobacco dependence is a significant public health problem.** Cigarette smoking is the leading cause of preventable death and illness in the United States and throughout the developed world. Smoking increases the odds of developing the most frequently diagnosed cancers and other leading causes of death, accounting for 1 in 5 deaths in the US each year. Due to restrictions in other communication outlets, the tobacco industry currently concentrates over 80% of its $8.1 billion annual marketing budget on retail environments, including **point-of-sale tobacco marketing (POSTM)**. Tobacco advertising and products are placed prominently in "power walls" near or behind cash registers in retail outlets like convenience stores and gas stations, such that all customers are exposed to this marketing. This widespread and frequent exposure to POSTM in smokers and nonsmokers alike is of great interest in tobacco control and cancer prevention research worldwide, and has led to recent bans of POSTM in 42% of countries in Europe. In this study, we aim to test whether repeated, real-world exposure to POSTM affects smoking behavior through heightened neural smoking cue reactivity and subjective craving.

**How are smokers influenced by point-of-sale tobacco marketing (POSTM)?** Past work suggests detrimental relationships between exposure to POSTM and other environmental smoking cues and smoking behavior in individuals and the larger population across countries, measures and study designs. Within current and recently quit smokers, field work consistently reports associations between POSTM exposure in naturalistic settings, and increased smoking cravings, purchase urges, and impulse purchases. The density of POSTM in an individual's neighborhood, a proxy for exposure, also influences smoking behavior; for example, longitudinal work finds that smokers are more likely to relapse during a quit attempt if they live near a POSTM store. In a virtual store study, enclosing the POSTM display reduced smokers' purchase attempts and urges to smoke. This body of research thus suggests that further regulation of POSTM would be beneficial from a cancer control perspective; however, causal evidence linking longitudinal, naturalistic exposure and smoking outcomes, as well as neural evidence supporting the mechanisms of cumulative and causal effects, would substantially bolster science-based policy making.

**The significance of geolocation tracking and ecological momentary assessment.** Geolocation tracking provides the unique ability to objectively and unobtrusively assess participants' exposure to POSTM outlets. The recent ubiquity of geolocation tracking built-in to smartphones provides the opportunity for incorporating this methodology into experimental designs with reduced participant burden. This is a significant improvement over prior POSTM exposure work, which is limited by reliance on self-reports of the timing and degree of POSTM exposure, or by the need to initiate or observe single, non-representative exposures. In PA, DE, and NJ, where data collection will take place, obtaining a local cigarette dealer license is mandatory for cigarette retailers and listings of licensed outlets are publicly available and updated monthly. Layering smokers' geolocation tracks onto maps of tobacco retail outlets allows objective quantification of an individual's exposure to POSTM in their natural environment. In parallel with geolocation tracking, we will sample participants' behaviors and craving throughout each day using EMA, to capture time-sensitive fluctuations in a representative manner. EMA optimally complements the naturalistic geolocation tracking data by tagging participants' location history with reports indicating natural smoking behavior and craving on a moment-to-moment basis.

**Combining responses to tobacco-related cues in the real world and cue-reactivity in the neuroimaging laboratory will provide a mechanistic understanding of how POSTM influences smokers.** The scientific premise for this study derives from theoretical models and empirical studies of addiction, which suggest that exposure to drug-cues, such as images of drug paraphernalia, enhances craving and consumption behavior in drug users, including smokers. Laboratory work has shown increased neural activity in regions associated with drug cue-reactivity as well as increased ratings of subjective craving in smokers after exposure to smoking cues such as pictures of cigarettes. Craving ratings scale positively with neural cue-reactivity, and both metrics predict smoking behaviors in a later ad-lib smoking session. Thus, laboratory experiments implicate neural smoking cue reactivity and cigarette craving as mechanisms linking exposure to smoking cues and behavior.

**Brain activity as a key, mechanistic indicator of message impact over time.** Functional neuroimaging allows an unobtrusive examination of both conscious and unconscious processes induced by exposure to standard smoking cues and mediated messages such as marketing materials. Our team and others have developed multi-method approaches to test the generalizability and predictive validity of laboratory-based neural effects to real-world behaviors. This work has shown that neural reactivity to persuasive messaging inside the fMRI scanner reliably predicts health behaviors, including reductions in smoking and sedentary behavior, above and beyond the predictive capacity of commonly used self-reports.

**Causal manipulation of exposure to tobacco marketing.** Most extant field work focused on POSTM, despite including large samples and naturalistic settings, has been correlational. The current study proposes to significantly extend prior findings by manipulating adult smokers' real-world, daily POSTM exposure over the course of one month. After an observation period of geolocation tracking and EMA, individuals will be randomly assigned to 1 of 3 groups. Two groups enter and make small, non-tobacco purchases at a store which displays POSTM (tobacco retailer condition) or a store that displays pro-cessation messaging (nontobacco retailer condition). Approaching the register for this purchase constitutes an exposure to POSTM (tobacco retailer condition) or pro-cessation marketing (nontobacco retailer condition). A third group receives no instruction to change their routine exposure to POSTM.

---

## Study Objectives

### Primary Objective

The primary objectives are to examine the relationships between smoking behavior, cigarette cravings, and exposure to point-of-sale tobacco marketing. We will examine whether experimental group assignment affects cigarette cravings and cigarette consumption during the intervention period relative to the baseline. For the subset of participants who undergo fMRI scanning, we will compare craving ratings and brain activity during different task conditions.

---

## Investigational Plan

### General Design

- **Study Type:** Interventional
- **Primary Purpose:** Other
- **Study Phase:** N/A
- **Interventional Study Model:** Parallel Assignment — Random assignment of retail environment (tobacco retailer, non-tobacco retailer, no store) to visit 5 times per week during the 4-week intervention period
- **Number of Arms:** 3
- **Masking:** Single (Investigator) — Investigator will not know the condition assignment of individual participants unless reassessment is triggered by the stopping rule.
- **Allocation:** Randomized
- **Enrollment:** 343 [Actual]

### Allocation to Interventional Group

Participants who completed the required tasks during the baseline period were randomized within blocks [blocked by gender (male, female, other) and smoking level (high, low; high was 20 cigarettes or greater per day)]. At the beginning of data collection, condition assignment was fully random; blocked-randomization was implemented part-way through the study on 12/01/2022.

### Study Measures

| Measure | Screen A | Screen B | Initial Call | Survey 1 (Day 0) | Baseline (Days 1–15) | Survey 2 (Day 15) | Intervention (Days 15–45) | Survey 3 (Day 45) | fMRI |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **File Submissions** | | | | | | | | | |
| Vaccination card (photo) | | X | | | | | | | |
| Location tracking (timeline export) | | X | | | | X | | | |
| Urine cotinine test (photo) | | | X | | | | | | X |
| Receipts (photos) | | | | | | | 20X | | |
| **Screening and Covariates** | | | | | | | | | |
| Eligibility screening | X | X | | | | | | | |
| Smoking behavior survey | | | X | | | X | | X | 1 item |
| Nicotine dependence survey (FTND) | | | X | | | X | | X | X |
| Smoking habits survey | | | X | | | | | X | |
| Smoking cessation intentions survey | | | X | | | | | X | |
| Smoking info exposure questionnaire | | | X | | | X | | X | |
| Smoking beliefs survey | | | X | | | | | X | |
| Smoking attitudes survey | | | X | | | | | X | |
| Social smoking norms survey | | | X | | | | | X | |
| Smoking motivation survey | | | X | | | | | | |
| Tobacco policy support questionnaire | | | X | | | | | X | |
| Social interactions & smoking survey | | | | | X (weekly) | | 4X (weekly) | | |
| Demographics survey | | | X | | | | | | |
| Stressful Life Experiences Inventory | | | | | X | | | | |
| Microaggressions survey | | | X | | X (weekly) | | 4X (weekly) | X | |
| Purpose in life survey | | | X | 1 item daily | | | 1 item daily | | |
| Smoker self-concept survey | | | X | | | | | X | |
| Perceived stress scale | | | X | | | | | X | |
| CES-D Depression scale | | | X | | | | | X | |
| Code switching survey | | | X | | | | | X | |
| Mindfulness (MAAS) | | | | | | | | | X |
| Impulsiveness (BIS-11) | | | | | | | | | X |
| Alcohol consumption | | | | | | | | | X |
| **Outcomes** | | | | | | | | | |
| Cigarette consumption – self-report | | | X | | | X | | X | |
| EMA text surveys – smoking and craving | | | | X | | | X | | |
| Cue reactivity task | | | | | X | | X | | X |

### Study Endpoints

#### Primary Study Endpoint

The primary endpoints will be cigarette smoking and craving at the end of the intervention period, measured through EMA multiple times daily. The primary endpoints for the fMRI scan session will be measured through fMRI scanning (brain activity).

#### Secondary Study Endpoints

*(To be detailed per analysis plan.)*

---

## Study Population and Duration of Participation

The target population is current smokers, ages 21–65, who have smoked at least 5 cigarettes a day for the past 6 months, are smartphone users, and live in PA/NJ/DE.

### Duration of Study Participation

The target behaviors (smoking frequency, cravings for cigarettes) will be assessed for an approximately 2 week baseline period and for an approximately 4 week intervention period. Thus, total study participation is expected to be approximately 6 weeks of active participation, with possible breaks in between the baseline and intervention periods. Total duration of participation will thus be approximately 2 months, with some exceptions. A subset of participants will be invited to complete an optional fMRI scan after their final online session; flexibility will be allowed in the timing of the scan session, which can be as long as 6 months after the final online session. This subset of participants will participate for a longer duration (total duration of participation can be up to 8 months [2 months of active participation, with a scan session up to 6 months later]).

### Total Number of Subjects and Sites

Our initial recruitment plan specified that "Recruitment will end when approximately 400 participants have been enrolled. It is expected that 400 enrolled participants will produce 180 evaluable subjects after attrition and data issues. Penn is the only site." See Section 6.1 for final plan, adjusting for COVID and other constraints.

### Inclusion Criteria

- Be between the ages of 21–65
- Smoke at least 5 cigarettes a day for the past 6 months
- Own an iPhone or Android smartphone that can be used on a daily basis
- Be residents of Pennsylvania, New Jersey, or Delaware
- Read and speak English fluently
- Fully vaccinated against COVID-19

### Exclusion Criteria

- Current enrollment or plans to enroll in a smoking cessation program in the next 3 months
- Plan to use nicotine substitutes or smoking cessation treatments in the next 3 months
- Pregnancy
- Refusal to install Google Maps or LifeData applications on mobile phone
- Inability or refusal to upload Google Timeline data after receiving instructions and guidance during or after the initial intake call
- During the first two weeks of the study, failure to complete the study tasks (response to at least 75% of the brief EMA survey questions)
- Urine cotinine testing at Session 1 indicates a non-smoker level of cotinine
- Phone functionality issues as assessed by trained recruiters during a phone call (reception/sending of text messages, use of geolocation tracking and LifeData applications, adequate battery life)
- Inability to provide informed consent or complete any of the study tasks as determined by the Principal Investigator and/or Study Physician
- Any physical or visual impairment that may prevent the individual from using a computer keyboard or completing any study tasks

**Additional criteria for fMRI component:**

- Urine cotinine concentration below 200 ng/mL at scanning session
- Currently or recently (within the last 5 years) receiving medical treatment for substance abuse (alcohol, opioids, cocaine, marijuana, or stimulants)
- Report consuming or planning to consume within 6 weeks: Benzodiazepines, Amphetamines, Methamphetamines, Cocaine, MDMA, Methadone, Barbiturates, PCP, Heroin, Oxycodone, Opiates, Buprenorphine
- Testing positive for any of the above drugs at the scan appointment
- Schizophrenia or psychosis, regardless of treatment status
- History of stroke or other neurological disorder likely to affect cognition
- Psychiatric hospitalization within the past year
- Propensity to experience claustrophobia
- Ferromagnetic metal in the body
- Metal in the body of an unverifiable origin
- Non-removable piercings
- Non-removable retainers or other dental work not compatible with fMRI
- Any orthopedic implant above the neck
- Weight exceeding 350 pounds
- Any medical condition or concomitant medication that could compromise participant safety or treatment
- Unable to schedule a scan within 6 months after completing the third Online Session

### Subject Recruitment

Direct recruitment may occur through newsletters, fliers, online ads/posts (e.g., Craigslist, Facebook, Instagram), newspaper listings, and/or ads on TV (or streaming media services). Recruitment materials may be posted by the study team or by BuildClinical. We will also collaborate with another smoking research group at the University of Pennsylvania. All recruitment material will include links (e.g., URLs, QR codes) directing potential participants to the screening survey (Screen A).

*Vulnerable Populations:* Not applicable

---

## Study Procedures

### Screening

#### Screen A

Those who express interest in the study by reacting to the recruitment efforts will be directed towards an online screening survey (Screen A) where they answer questions relevant to their eligibility for the study and provide their contact information.

- Administered online via RedCap or BuildClinical; estimated to take less than 5 minutes.
- Ineligible respondents will receive an email informing them.
- Eligible respondents will be emailed and/or texted a link to Calendly to sign up for an initial phone call.

#### Initial Call

During the initial call, participants will be informed about the study, including the risks and benefits of participation, and will be given the opportunity to ask questions. Eligibility criteria will be confirmed on this call as needed.

- Conducted over the phone (Google Voice); approximately 30 minutes. Researcher enters participant responses into RedCap.
- Eligible and interested participants will be invited via email to complete Screen B within 1 month.

#### Screen B

Screen B begins with a RedCap e-consent form, guides potential participants to provide their shipping address and submit a picture of their COVID-19 vaccination card, then walks them through downloading/setting up Google Maps and exporting their Google timeline data.

- Administered online using RedCap and Qualtrics; 5–15 minutes of active participation.
- Researchers confirm: (A) participant lives in the study area using timeline data and shipping address, and (B) participant is fully vaccinated against COVID-19.

#### Mailing Materials

Eligible individuals will be mailed a box containing study materials, including the urine cotinine test, KN95/KF94 or N95 masks, and a Greenphire Clincard. Upon receipt, participants will be given instructions to enroll and begin participation by completing Session 1.

### Study Observational Phase

#### Online Session 1 (S1)

Participants will read through and consent to the full study, complete physiological measurements (urine cotinine) and self-report measures, receive EMA task instructions, and install/set up RealLife Exp (the EMA app).

- Administered over RedCap and Qualtrics; 30–60 minutes.
- Participants with cotinine below the eligibility threshold will be excluded from continuing.

#### Observational Phase

The baseline period will begin after completion of Session 1 and will last for 14 days. During this period, participants will complete EMA and location tracking.

- Participants excluded for non-compliance if they respond to fewer than 75% of EMA prompts.
- Following the baseline period, participants will be assigned to an experimental condition.

### Study Interventional Phase

#### Online Session 2

Participants complete self-report measures, an image rating task, geolocation data export/upload, EMA setup and practice, and instructions/practice for the intervention tasks.

- Administered over Qualtrics; 30–60 minutes. Participants are encouraged to complete within 4 days, no longer than 1 week.

#### Intervention Phase

The 4-week intervention period begins after Session 2. All participants complete EMA, location tracking, and weekly surveys. The two experimental groups (tobacco retailer and nontobacco retailer) are asked to enter a specific store 5 times per week for 4 weeks. The control group will not be asked to enter a store.

#### Online Session 3

Following the intervention period, participants complete surveys, an image rating task, and geolocation data export/upload. Participants are encouraged to complete within 4 days, no longer than 1 week. At the end of the session, participants are instructed on how to uninstall study-related smartphone applications and turn off location tracking. Those not eligible for the scan session will be provided with a debriefing form and a Quit Resources document.

#### Optional fMRI Session

- **fMRI Screening:** Participants who complete Session 3 and are potentially eligible may be invited to complete an additional optional fMRI screening survey.
- **fMRI Session:** This is a 2-hour session. After confirming COVID-19 screening requirements, researchers will review the consent addendum, confirm eligibility via urine sample, and provide safety/task instructions. During the 1-hour scan component, participants will complete an image rating task.

### Unscheduled Visits

At the end of Screen B and at the end of each online session, participants will be invited to provide feedback on their experience via an open-answer text box. The study team may follow up by email or phone to clarify feedback as needed.

### Subject Withdrawal and Exclusion

Subjects may withdraw from the study at any time without penalty. Participation may also be stopped at the Investigator's discretion for lack of adherence to study instructions, or if exclusion is deemed best for subject safety or health.

- **Online Session 1:** Participants excluded due to cotinine test results will be paid $75 for tasks completed.
- **Baseline Period:** Excluded or withdrawn participants will be paid at $4 per day with ≥75% EMA compliance.
- **Intervention Period:** Participants who do not complete required tasks (e.g., fewer than 20 store receipts, EMA compliance below 75%) will not receive the study completion bonus. Standard compensation applies for EMA compliance ($4/day at ≥75%) and receipt submission ($5 per verified daily receipt).
- Withdrawn and excluded participants who complete an optional offboarding call will be compensated at $15/hour.
- **fMRI Session:** Participants excluded or asked to reschedule after arriving will be paid $15 for their time via ClinCard or petty cash.

#### Data Collection and Follow-up for Withdrawn Subjects

All withdrawn and excluded participants are sent instructions to turn off location tracking and delete the RealLife Exp app. They are also informed of the option to schedule an optional offboarding call (compensated at $15/hour). These participants will also be sent a link to submit geolocation data for a final time for an additional $5 payment (estimated 20 minutes at $15/hour).

### Early Termination Visits

All withdrawn and excluded participants are sent instructions to turn off location tracking and delete the RealLife Exp app. An optional offboarding call is available (compensated at $15/hour). Participants will also be sent a link to submit geolocation data for a final time for an additional $5 payment.

### Safety Evaluation

Safety evaluation was conducted at data collection milestones of approximately 60 and 120 participants (approximately 20 and 40 per group, respectively):

1. Assess the distribution of each participant's daily cigarette consumption during the baseline period and during weeks 3–4 of the intervention period.
2. Participants identified as "increased smokers" if their average daily cigarette consumption during the final 2 weeks of the intervention period is more than 3 standard deviations above their baseline mean.
3. If the number of "increased smokers" in the Tobacco retailer condition is significantly (*p* ≤ .01) greater than in the control condition, this will trigger a reassessment by the study team and may result in termination of that arm of the study and reassignment of future participants to the other two groups.

---

## Statistical Plan

### Sample Size and Power Determination

Our initial target was to obtain 60 complete datasets per intervention condition (total N = 180). Due to pandemic-related constraints and time delays, we were unable to reach this goal. Prior to looking at the data, we elected to randomize more individuals into the experimental conditions than to the control condition. Using PANGEA, we estimated that with at least 40 complete datasets in each intervention condition, we could detect interaction effects (time × group) sized d = 0.1 with 95% power. We ultimately randomized 105 to the Non-tobacco retailer condition, 107 to the Tobacco retailer condition, and 70 to the Control condition, resulting in 175 complete datasets. Power analysis suggests that with N=32 and at least 10 observations per condition in the fMRI dataset, we have >80% power to detect effects of *d* = .2 within person.

### Statistical Methods

Behavioral data (EMA, smoking behavior) and neural activity aggregates from regions of interest will be analyzed using R with multi-level regression and repeated measures ANOVA, or alternative appropriate statistics given observed distributions.

fMRI data will be analyzed using Statistical Parametric Mapping (SPM; Wellcome Trust Centre for Neuroimaging) and NiPype. Prior to analysis, standard data screening/cleaning procedures will be applied. Neuroimaging analysis will begin with slice-time correction, realignment, coregistration of functional and structural images, and normalization to the standard Montreal Neurological Institute (MNI) brain. Response amplitude (percent signal change) within each ROI will be extracted using SPM or nipype tools; primary tests will be performed in R, α=.05, two-tailed. Whole-brain exploratory analyses will be performed in SPM12, thresholded to p<.05, FDR-corrected.

### Control of Bias and Confounding

Participants who complete the required baseline tasks will be randomized. All participants have an equal chance to be in any condition. Conditions are coded with a numeric value so they can be analyzed by researchers blinded to participants' specific group assignment.

#### Baseline Data

Baseline and demographic characteristics will be summarized by standard descriptive statistics (mean and standard deviation for continuous variables; standard percentages for categorical variables).

#### Analysis of Primary Outcome of Interest

**Daily cigarette and craving analyses**

**Hypothesis 1:** Reported craving will be higher for those in the Tobacco retailer condition, relative to the Control and Nontobacco retailer conditions, during the intervention phase, but not the baseline phase. A linear mixed effects model will be used. A binary *Study Phase* variable will indicate baseline (0) versus intervention (1). Two dummy-coded condition variables will be created: *Control condition* (1 = Control, 0 = other) and *Nontobacco retailer condition* (1 = Nontobacco, 0 = other).

*Level 1 model:*

> Craving_it = β_0i + β_1i × StudyPhase_it + e_it

*Level 2 model:*

> β_0i = γ_00 + γ_01 × ControlCondition_i + γ_02 × NontobaccoRetailerCondition_i + u_0i
>
> β_1i = γ_10 + γ_11 × ControlCondition_i + γ_21 × NontobaccoRetailerCondition_i + u_1i

Parameters γ_11 and γ_21 test the key hypotheses.

**Hypothesis 2:** Reported cigarettes smoked will be higher for those in the Tobacco retailer condition, relative to the Control and Nontobacco retailer conditions, during the intervention phase, but not the baseline phase. A parallel model structure to Hypothesis 1 is used, with smoking as the outcome:

> Smoking_it = β_0i + β_1i × StudyPhase_it + e_it

**fMRI-related analyses**

**Hypothesis 1:** Neural activity in smoking cue reactivity regions will be greater in response to standardized smoking cues than non-smoking cues. A binary *TaskCondition* variable will indicate standard smoking cue blocks (1) vs. non-smoking cue blocks (0). Linear mixed effects model:

> lme(ROI ~ TaskCondition, random = ~ 1 | Participant / Session)

**Hypothesis 2:** Neural activity in smoking cue reactivity regions will be greater in response to tobacco retail images than nontobacco retail images. A parallel model to Hypothesis 1 is used, where *TaskCondition* represents tobacco retail images vs. nontobacco retail images.

#### Interim Analysis

At approximately 60 and 120 participants enrolled, we will test whether individuals in the Tobacco retailer condition have significantly changed the number of cigarettes smoked per day. If this group changes their cigarette consumption by a clinically significant level, we will stop assigning participants to that group and assign all further participants equally to the other groups.

---

## Safety and Adverse Events

### Definitions

#### Adverse Event

An adverse event (AE) is any symptom, sign, illness or experience that develops or worsens in severity during the course of the study. Intercurrent illnesses or injuries should be regarded as adverse events.

Incidental findings in the fMRI component are considered adverse events if the finding: results in study withdrawal; is associated with a serious adverse event; is associated with clinical signs or symptoms; leads to additional treatment or diagnostic tests; or is considered by the investigator to be of clinical significance.

#### Serious Adverse Event

A serious adverse event (SAE) is any AE that is: fatal; life-threatening; requires or prolongs hospital stay; results in persistent or significant disability or incapacity; required intervention to prevent permanent impairment or damage; a congenital anomaly or birth defect; or an important medical event.

### Recording of Adverse Events

Smoking behavior will be self-reported at each study session and multiple times daily during the baseline and intervention periods. Experimenters will record medical or other life events that may be considered adverse events as reported by participants. Information on all adverse events will be recorded in the source document immediately upon discovery and in the appropriate adverse event module of the case report form (CRF).

### Relationship of AE to Study

- **Definitely Related** — Clear evidence of a causal relationship; other contributing factors can be ruled out.
- **Probably Related** — Evidence suggests a causal relationship; influence of other factors is unlikely.
- **Potentially Related** — Some evidence of a causal relationship; other factors may have contributed.
- **Unlikely to be Related** — Temporal relationship makes a causal relationship improbable; other explanations exist.
- **Not Related** — AE is completely independent of study procedures; evidence exists of another definitive etiology.

The PI will make this determination.

### Reporting of Adverse Events and Unanticipated Problems

The Investigator will promptly notify the Penn IRB of all on-site unanticipated, Serious Adverse Events related to the research activity. Written reports will be filed using HS-ERA within 10 working days. All instances of related SAEs will be reported to the appropriate IRB and the NCI Program Officer within 24 hours of discovery; probably or definitely related SAEs will be reported to the appropriate IRBs within 10 days of occurrence.

#### Follow-up Report

If an AE has not resolved at the time of the initial report and new information arises that changes the investigator's assessment, a follow-up report should be submitted to the IRB. The investigator is responsible for ensuring that all related SAEs are followed until either resolved or stable.

#### Investigator Reporting: Notifying the Study Sponsor

1. Report all instances of related SAEs to the NCI Program Officer within 24 hours of occurrence or discovery.
2. Inform all members of the study team actively involved in data collection about any and all reports of adverse events.
3. Notify the NCI Program Officer of any suspension/termination of IRB approval and any actions taken by the IRBs with regard to data safety monitoring within 5 days of IRB notification or approval.

#### Data and Safety Monitoring Plan

During the course of the study, data and safety monitoring were performed on an ongoing basis by the Principal Investigator (Dr. Emily Falk, Ph.D.), project staff, and IRB at the University of Pennsylvania. The Research Director, Dr. Nicole Cooper, Ph.D., collaborated in the monitoring process. Any deviations and potentially serious and related adverse events were reviewed by Dr. Falk and Dr. Cooper.

Monitoring activities included:

- **Protocol Monitoring:** Survey of activities associated with protocol adherence such as study visit deviations and violation of inclusion/exclusion criteria.
- **Data Auditing:** Safety and efficacy review. A Study Binder Review will include: IRB Protocol, Consent Form and Amendment Approvals, IRB Closure Letter, Human Subjects Certifications, Protocol and Amendment Signature Pages, Curriculum Vitae, Financial Disclosure Questionnaires, and Monitoring Log.
- **Assessing Adverse Events:** Monitoring conducted in real time under the supervision of Dr. Falk and Dr. Cooper.
- **Adverse Event Reporting:** Any serious and related adverse event case reviewed by Dr. Falk. After de-identification, all SAEs will be reported to the University of Pennsylvania IRB, the CTSRMC, and the funding agency.
- **Incidental Findings:** If any incidental findings are noted, the subject will be advised to consult a neurologist.
- **Data Security:** Using network firewall technologies, the database prevents unauthorized internal/external access and malicious intent. Controlled user access ensures only authorized personnel can view, access, and modify study data.
- **Staff Training:** Explanation and review of the protocol, a training period observed by senior staff, review of applicable regulations, and a manual of Standard Operating Procedures. All research personnel have completed the CITI program or equivalent, as well as HIPAA Compliance Training.

---

## Study Administration, Data Handling and Record Keeping

### Confidentiality

Information about study subjects will be kept confidential and managed according to the requirements of the Health Insurance Portability and Accountability Act of 1996 (HIPAA). Those regulations require a signed subject authorization informing the subject of: what protected health information (PHI) will be collected; who will have access to it and why; who will use or disclose that information; and the rights of a research subject to revoke their authorization for use of their PHI.

Wherever feasible, identifiers will be removed from study-related information. Computer-based files will only be made available to personnel involved in the study through access privileges and passwords. Participants will be informed that this research is covered by a Certificate of Confidentiality from the National Institutes of Health.

### Data Collection and Management

- **GENERAL:** All information collected will be treated as strictly confidential. A dual ID system is used: Screen A assigns a RedCap record ID, while enrolled participants receive a separate study ID.
- **GREENPHIRE:** Participant information (name, date of birth, address, SSN) stored for payment via Greenphire ClinCard.
- **REDCAP:** Online database system and survey platform. Access only to authorized study staff. Used for e-consent, linking categories of subject identifiers, and recording results of the urine drug screen for fMRI participants.
- **BUILDCLINICAL:** Data-driven software platform for participant recruitment via social media and digital platforms. HIPAA compliant with SSL encryption.
- **PARTICIPANT CONTACT:** Participants provided with the study Google Voice number and Gmail address within the lab's GSuite (Falklab.org).
- **QUALTRICS:** Only authorized study staff will have access. Survey data coded with study identifiers.
- **LIFEDATA:** Third-party EMA tool using the RealLife Exp smartphone application. Data coded with study ID and a unique LifeData-generated user number.
- **GOOGLE MAPS:** Geolocation data collected through Google Maps app and Google Timeline. Participants submit a downloaded .json or .kml file via Qualtrics or PennBox.
- **fMRI DATA:** Neuroimaging data stored and archived on (1) a secured, password-protected computer at the scanner site and (2) on Flywheel, a cloud-based research platform.
- **ASC SERVER:** Submitted location data files and neuroimaging data stored on a secure server maintained by the Annenberg School for Communication (ASC), accessible only to the study team.
- **PENNBOX:** Cloud-based collaboration service for securely managing and sharing files. Files containing identifiable data will be stored in a separate, password-protected folder.
- **STUDY LOGISTICS:** Study progress tracked through a spreadsheet coded by study identifiers, stored in Google Drive, Qualtrics, RedCap, and/or Box.

---

## Study Monitoring, Auditing, and Inspecting

### Study Monitoring Plan

The study PI will be responsible for the ongoing quality and integrity of the research study, in collaboration with the Research Director.

### Auditing and Inspecting

The investigator will permit study-related monitoring, audits, and inspections by the EC/IRB, the sponsor, government regulatory bodies, and University compliance and quality assurance groups of all study related documents. The investigator will ensure the capability for inspections of applicable study-related facilities.

---

## Ethical Considerations

### Risks

- Risk of unintentional breach of confidentiality, mitigated by SSL protocol, database physical and electronic protection, and controlled user access.
- Past literature suggests potential negative consequences of increased exposure to POST-marketing. However, the study manipulation does not involve a quit attempt and does not exceed everyday levels of POST-marketing exposure.
- For the duration of the COVID-19 pandemic, entry into retail stores may increase participants' risk of COVID-19 exposure. To reduce transmission risks, participants are provided KN95/KF94 or N95 respirators and are required to be vaccinated.
- **Optional fMRI session:** Safety concerns in the MR environment (burns or bodily injury from ferrous metal). Participants with contraindications for MR studies are excluded. Risk of claustrophobia addressed via exclusion criteria; participants may stop the study at any time. Risk of discomfort from fMRI scanner noise minimized by providing earplugs. Risk of incidental findings (e.g., brain lesion): Structural MRI scans will not be read by a radiologist; participants are informed of this before consenting.

### Benefits

There are no direct benefits to subjects other than monetary and gift card compensation. Participants may benefit from heightened awareness of how point-of-sale marketing affects their smoking behavior and decision-making.

### Risk Benefit Assessment

Given the minimal risk of the study and the great potential benefit for understanding the relationship between the brain and behavior, the potential benefits to society outweigh the risks.

### Informed Consent Process / HIPAA Authorization

- **Screen B Consent:** Explains the purpose and nature of the screening. Includes an optional opt-out section for location history data from before the study period. Declining does not preclude participation.
- **Full Study Consent:** Participants will read and be sent a PDF of the informed consent form for electronic signature via RedCap's HIPAA-compliant e-signature system. Experimenters will review this form during the intake call.
- **Optional fMRI Session Consent:** Researchers will review the consent addendum document with participants at the in-person session. Participants provide written informed consent via RedCap.

---

## Study Finances

### Funding Source

This study is financed by an R01 grant from the National Cancer Institute at the US National Institute of Health.

### Conflict of Interest

The investigators declare no conflicts of interest.

### Subject Stipends or Payments

Each participant can earn up to **$500.00** through a Greenphire ClinCard for completing all remote study requirements. Participants eligible for the optional in-person fMRI scan session may receive additional compensation of **$95**.

*Conditions 1 & 2 = Tobacco and Nontobacco retailer conditions; Condition 3 = Control*

| Period | Task | Payment Rate | Max Possible | Max Total STORE | Max Total CONTROL |
|---|---|---|:---:|:---:|:---:|
| **Online Session 1** | Cumulative payment for Screens A & B, initial call, and Session 1 | — | $95 | **$95 at Session 1** | **$95 at Session 1** |
| **Baseline (2 weeks)** | EMA response | $28/week × 2 weeks for ≥75% compliance | $55 | **$90 at Session 2** | **$75 at Session 2** |
| **Online Session 2** | Session 2 | — | $20 | | |
| **Intervention (4 weeks)** | Store purchase funds (week 1) | $3/visit × 5 visits/week | $15 | | |
| | Store purchase funds (week 2) | $3/visit × 5 visits/week | $15 | **$15 after Intervention Week 1** | n/a |
| | Store purchase funds (week 3) | $3/visit × 5 visits/week | $15 | **$15 after Intervention Week 2** | n/a |
| | Store purchase funds (week 4) | $3/visit × 5 visits/week | $15 | **$15 after Intervention Week 3** | n/a |
| | EMA response | $28/week × 4 weeks for ≥75% compliance | $110 | **$270 at Session 3** | **$330 at Session 3** |
| | Store receipt photographs | $5/receipt × 20 receipts (cond. 1 or 2) | $100 | | |
| | Weekly survey | $2.50 each × 4 weekly surveys | $10 | | |
| **Online Session 3** | Session 3 | — | $20 | | |
| | Study completion | $30 for cond. 1 or 2; $190 for cond. 3 | $30 / $190 | | |
| **Maximum (remote tasks)** | | | **$500** | **$500** | **$500** |
| **OPTIONAL In-Person Session** | 2-hour session (includes 1-hour fMRI scan) | — | $95 | **$95 at the optional In-Person Session** | **$95 at the optional In-Person Session** |
| **Maximum (all tasks)** | | | **$595** | **$595** | **$595** |

---

## Publication Plan

This study will be conducted in accordance with the following publication and data sharing policies and regulations:

- **NIH Public Access Policy:** Final peer-reviewed manuscripts arising from NIH funds will be submitted to PubMed Central upon acceptance for publication.
- **NIH Data Sharing Policy and Clinical Trial Information Policy:** This trial has been registered at ClinicalTrials.gov and results information will be submitted accordingly.
- **Data Sharing:** Final research data, with identity-related information deleted, will be made available to the scientific community upon request after the study's primary results have been published. Non-imaging data will be shared in spreadsheet format; fMRI data in NIFTI format. Geolocation data will be shared at an aggregate level with restrictions to protect participant privacy. Please fill out a form [here](https://tinyurl.com/geoscan-data-request) to request data access.
- **Imaging Data:** Will be made available through a secure file-sharing interface once the main findings have been published.
- **Study Tasks and Code:** Will be made available on the Falk Lab GitHub account at [https://github.com/cnlab/Geoscan-public/](https://github.com/cnlab/geoscan-public/).

---

## References

### Summary References

1. Center for Public Health Systems Science. Point-of-sale report to the nation. State and Community Tobacco Control Research.
2. Kirchner, T. R. et al. Geospatial Exposure to Point-of-Sale Tobacco. *Am J Prev Med* 45, 379–385 (2013).
3. Wakefield, M., Germain, D. & Henriksen, L. The effect of retail cigarette pack displays on impulse purchase. *Addiction* 103, 322–328 (2008).
4. Jasinska, A. J. et al. Factors modulating neural reactivity to drug cues in addiction: A survey of human neuroimaging studies. *Neurosci Biobehav Rev* 38, 1–16 (2014).
5. Engelmann, J. M. et al. Neural substrates of smoking cue reactivity: A meta-analysis of fMRI studies. *NeuroImage* 60, 252–262 (2012).
6. Janes, A. C. et al. Brain Reactivity to Smoking Cues Prior to Smoking Cessation Predicts Ability to Maintain Tobacco Abstinence. *Biol Psychiatry* 67, 722–729 (2010).
7. McClernon, F. J. et al. 24-h smoking abstinence potentiates fMRI-BOLD activation to smoking cues in cerebral cortex and dorsal striatum. *Psychopharmacology* 204, 25–35 (2008).
8. Bedi, G. et al. Incubation of Cue-Induced Cigarette Craving During Abstinence in Human Smokers. *Biol Psychiatry* 69, 708–711 (2011).

### Background References

1. US Department of Health and Human Services. The Health Consequences of Smoking - 50 Years of Progress: A Report of the Surgeon General. (2014).
2. National Center for Chronic Disease Prevention and Health Promotion (US) Office on Smoking and Health. *The Health Consequences of Smoking—50 Years of Progress: A Report of the Surgeon General*. (CDC, 2014).
3. Smoking, C. O. on & Health. Smoking and Tobacco Use; Fact Sheet; Tobacco-Related Mortality.
4. Federal Trade Commission. Cigarette Report for 2011. (2013).
5. Wakefield, M. A. et al. Tobacco industry marketing at point of purchase after the 1998 MSA billboard advertising ban. *Am J Public Health* 92, 937–940 (2002).
6. Henriksen, L. Comprehensive tobacco marketing restrictions: promotion, packaging, price and place. *Tob Control* 21, 147–153 (2012).
7. Truth Initiative. How big is Big Tobacco's marketing budget? *Truth Initiative* (2016).
8. Center for Public Health Systems Science. Point-of-Sale Report to the Nation: The Tobacco Retail and Policy Landscape. (2014).
9. Center for Public Health Systems Science. Point-of-Sale Report to the Nation: The Tobacco Retail and Policy Landscape. (2014).
10. Feld, A. L. How to Conduct Store Observations of Tobacco Marketing and Products. *Prev Chronic Dis* 13 (2016).
11. The War in the Store — Counter Tobacco. http://countertobacco.org/the-war-in-the-store/.
12. Evidence brief: Tobacco point-of-sale display bans — WHO/Europe.
13. Kirchner, T. R. et al. Geospatial Exposure to Point-of-Sale Tobacco. *Am J Prev Med* 45, 379–385 (2013).
14. Kirchner, T. R. et al. Individual Mobility Patterns and Real-time Geo-spatial Exposure to Point-of-sale Tobacco Marketing. In *Proceedings of the Conference on Wireless Health* 8:1–8:8 (ACM, 2012).
15. Shiffman, S., Stone, A. A. & Hufford, M. R. Ecological momentary assessment. *Annu Rev Clin Psychol* 4, 1–32 (2008).
16. Engelmann, J. M. et al. Neural substrates of smoking cue reactivity: a meta-analysis of fMRI studies. *Neuroimage* 60, 252–262 (2012).
17. McClernon, F. J. et al. Abstinence-Induced Changes in Self-Report Craving Correlate with Event-Related fMRI Responses to Smoking Cues. *Neuropsychopharmacology* 30, 1940–1947 (2005).
18. McClernon, F. J. et al. Hippocampal and Insular Response to Smoking-Related Environments: Neuroimaging Evidence for Drug-Context Effects in Nicotine Dependence. *Neuropsychopharmacology* 41, 877–885 (2016).
19. Li, L. et al. Impact of point-of-sale tobacco display bans: findings from the International Tobacco Control Four Country Survey. *Health Educ Res* 28, 898–910 (2013).
20. Henriksen, L. et al. A longitudinal study of exposure to retail cigarette advertising and smoking initiation. *Pediatrics* 126, 232–238 (2010).
21. Quinn, C. et al. Economic evaluation of the removal of tobacco promotional displays in Ireland. *Tob Control* 20, 151–155 (2011).
22. Robertson, L. et al. A systematic review on the impact of point-of-sale tobacco promotion on smoking. *Nicotine Tob Res* 17, 2–17 (2015).
23. Burton, S. et al. The association between seeing retail displays of tobacco and tobacco smoking and purchase. *Addiction* 107, 169–175 (2012).
24. Carter, O. B. J. et al. Impact of a point-of-sale tobacco display ban on smokers' spontaneous purchases. *Tob Control* 24, e81–6 (2015).
25. Carter, O. B. J. et al. The effect of retail cigarette pack displays on unplanned purchases. *Tob Control* 18, 218–221 (2009).
26. Wakefield, M. et al. The effect of retail cigarette pack displays on impulse purchase. *Addiction* 103, 322–328 (2008).
27. Siahpush, M. et al. The association of exposure to point-of-sale tobacco marketing with quit attempt and quit success. *Int J Environ Res Public Health* 13, 203 (2016).
28. Siahpush, M. et al. The association of point-of-sale cigarette marketing with cravings to smoke. *Tob Control* 25, 402–405 (2016).
29. Henriksen, L. et al. Is adolescent smoking related to the density and proximity of tobacco outlets and retail cigarette advertising near schools? *Prev Med* 47, 210–214 (2008).
30. Lipperman-Kreda, S. et al. Density and proximity of tobacco outlets to homes and schools: relations with youth cigarette smoking. *Prev Sci* 15, 738–744 (2014).
31. Pearce, J. et al. The neighbourhood effects of geographical access to tobacco retailers on individual smoking behaviour. *J Epidemiol Community Health* 63, 69–77 (2009).
32. Cantrell, J. et al. The impact of the tobacco retail outlet environment on adult cessation and differences by neighborhood poverty. *Addiction* 110, 152–161 (2015).
33. Reitzel, L. R. et al. The effect of tobacco outlet density and proximity on smoking cessation. *Am J Public Health* 101, 315–320 (2011).
34. Chaiton, M. O. et al. Tobacco retail availability and risk of relapse among smokers who make a quit attempt. *Tob Control* (2017). doi:10.1136/tobaccocontrol-2016-053490
35. Kim, A. E. et al. Influence of point-of-sale tobacco displays and graphic health warning signs on adults: evidence from a virtual store experimental study. *Am J Public Health* 104, 888–895 (2014).
36. State Tobacco Cessation Coverage. http://slati.lung.org/slati/.
37. Tobacco Products Tax Licenses Current Revenue | PA Open Data Portal. https://data.pa.gov/Licenses-Certificates/Tobacco-Products-Tax-Licenses-Current-Revenue/ut72-sft8.
38. Kirchner, T. R. et al. Geospatial Exposure to Point-of-Sale Tobacco. *Am J Prev Med* 45, 379–385 (2013).
39. Shadel, W. G. et al. Exposure to pro-smoking media in college students: does type of media channel differentially contribute to smoking risk? *Ann Behav Med* 45, 387–392 (2013).
40. Shiffman, S. Ecological momentary assessment (EMA) in studies of substance use. *Psychol Assess* 21, 486–497 (2009).
41. Berkman, E. T. et al. Using SMS text messaging to assess moderators of smoking reduction: Validating a new tool for ecological measurement of health behaviors. *Health Psychol* 30, 186–194 (2011).
42. Konrath, S. et al. Can Text Messages Increase Empathy and Prosocial Behavior? The Development and Initial Validation of Text to Connect. *PLoS One* 10, e0137585 (2015).
43. Carter, B. L. & Tiffany, S. T. Meta-analysis of cue-reactivity in addiction research. *Addiction* 94, 327–340 (1999).
44. Tiffany, S. T. A cognitive model of drug urges and drug-use behavior: role of automatic and nonautomatic processes. *Psychol Rev* 97, 147–168 (1990).
45. Zubieta, J.-K. et al. Regional cerebral blood flow responses to smoking in tobacco smokers after overnight abstinence. *Am J Psychiatry* 162, 567–577 (2005).
46. Brody, A. L. et al. Brain metabolic changes during cigarette craving. *Arch Gen Psychiatry* 59, 1162–1172 (2002).
47. Shiffman, S. et al. Smoker reactivity to cues: effects on craving and on smoking behavior. *J Abnorm Psychol* 122, 264–280 (2013).
48. Conklin, C. A. et al. Bringing the real world into the laboratory: Personal smoking and nonsmoking environments. *Drug Alcohol Depend* 111, 58–63 (2010).
49. Conklin, C. A. Environments as cues to smoke: Implications for human extinction-based research and treatment. *Exp Clin Psychopharmacol* 14, 12–19 (2006).
50. Wang, A.-L. et al. Content Matters: Neuroimaging Investigation of Brain and Behavioral Impact of Televised Anti-Tobacco Public Service Announcements. *J Neurosci* 33, 7420–7427 (2013).
51. Falk, E. B. et al. From neural responses to population behavior: neural focus group predicts population-level media effects. *Psychol Sci* 23, 439–445 (2012).
52. Falk, E. B. et al. Functional brain imaging predicts public health campaign success. *Soc Cogn Affect Neurosci* 11, 204–214 (2016).
53. Pegors, T. K. et al. Predicting behavior change from persuasive messages using neural representational similarity and social network analyses. *Neuroimage* 157, 118–128 (2017).
54. Cooper, N. et al. Coherent activity between brain regions that code for value is linked to the malleability of human behavior. *Sci Rep* 7, 43250 (2017).
55. Green, A. E. et al. Young Adult Smokers' Neural Response to Graphic Cigarette Warning Labels. *Addict Behav Rep* 3, 28–32 (2016).
56. Cooper, N. et al. Brain activity in self- and value-related regions in response to online antismoking messages predicts behavior change. *J Media Psychology* 27, 93–108 (2015).
57. Tompson, S. et al. Grounding the neuroscience of behavior change in the sociocultural context. *Curr Opin Behav Sci* 5, 58–63 (2015).
58. Vezich, S. et al. Persuasion neuroscience: new potential to test dual process theories. In *Social Neuroscience: Biological approaches to social Psychology* (2015).
59. Falk, E. B. et al. Neural activity during health messaging predicts reductions in smoking above and beyond self-report. *Health Psychol* 30, 177–185 (2011).
60. Falk, E. B. et al. Predicting persuasion-induced behavior change from the brain. *J Neurosci* 30, 8421–8424 (2010).
61. Falk, E. B. et al. Neural Prediction of Communication-Relevant Outcomes. *Commun Methods Meas* 9, 30–54 (2015).
62. Falk, E. B. et al. Self-affirmation alters the brain's response to health messages and subsequent behavior change. *Proc Natl Acad Sci* 112, 1977–1982 (2015).
63. Cascio, C. N. et al. Buffering social influence: neural correlates of response inhibition predict driving safety in the presence of a peer. *J Cogn Neurosci* (2014).
64. Cascio, C. N. et al. Health communications: Predicting behavior change from the brain. In *Social Neuroscience and Public Health* 57–71 (Springer New York, 2013).
65. Berkman, E. T. & Falk, E. B. Beyond Brain Mapping: Using Neural Measures to Predict Real-World Outcomes. *Curr Dir Psychol Sci* 22, 45–50 (2013).
66. Berkman, E. T. et al. In the trenches of real-world self-control: neural correlates of breaking the link between craving and smoking. *Psychol Sci* 22, 498–506 (2011).
67. Kang, Y. et al. Dispositional Mindfulness Predicts Adaptive Affective Responses to Health Messages and Increased Exercise Motivation. *Mindfulness* 8, 387–397 (2017).
68. Falk, E. B. et al. Creating buzz: the neural correlates of effective message propagation. *Psychol Sci* 24, 1234–1242 (2013).
69. O'Donnell, M. B. et al. Big data in the new media environment. *Behav Brain Sci* 37, 94–95 (2014).
70. Lopez, R. B. et al. A balance of activity in brain control and reward systems predicts self-regulatory outcomes. *Soc Cogn Affect Neurosci* 12, 832–838 (2017).
71. Falk, E. B. et al. Neural Responses to Exclusion Predict Susceptibility to Social Influence. *J Adolesc Health Care* 54, S22–S31 (2014).
72. Brewer, J. A. et al. Pretreatment brain activation during stroop task is associated with outcomes in cocaine-dependent patients. *Biol Psychiatry* 64, 998–1004 (2008).
73. Kosten, T. R. et al. Cue-induced brain activity changes and relapse in cocaine-dependent patients. *Neuropsychopharmacology* 31, 644–650 (2006).
74. Paulus, M. P. et al. Neural activation patterns of methamphetamine-dependent subjects during decision making predict relapse. *Arch Gen Psychiatry* 62, 761–768 (2005).
75. Chua, H. F. et al. Self-related neural response to tailored smoking-cessation messages predicts quitting. *Nat Neurosci* 14, 426–427 (2011).
76. Baek, E. C. et al. The Value of Sharing Information: A Neural Account of Information Transmission. *Psychol Sci* 28, 851–861 (2017).
77. Scholz, C. et al. A neural model of valuation and information virality. *Proc Natl Acad Sci USA* 114, 2881–2886 (2017).
