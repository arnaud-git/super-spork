using JuMP
using CPLEX

##########MODEL##########
m = Model() #Model of the OR and the ICU

##########VARIABLES##########
@variable(m,r[1:C,1:T,1:K], Bin)
#r[c,t,k] = 1 if the surgeon c is assigned to the block k on the day t
@variable(m,x[1:I,1:T,1:K], Bin)
#x[i,t,k] = 1 if the patient i is assigned to the block k on the day t
@variable(m,v[1:I,1:T,1:L], Bin)
#v[i,t,r] = 1 if the patient i is assigned to the recovery bed r on the day t
@variable(m,γ[1:I,1:T], Bin)
#γ[i,t] = 1 if the patient i uses a bed in the ICU on the day t
@variable(m,λ[1:I,1:I], Bin)
#λ[i,j] = 1 if the patient i precedes the patient j in an OR
@variable(m,ν[1:I,1:I], Bin)
#ν[i,j] = 1 if the patient i precedes the patient j in a recovery bed
@variable(m,h[1:I] >= 0, Int)
#h[i] is the time of the beginning of the intervention of the patient i
@variable(m,Cope[1:T,1:K], Int)
#Cope[t,k] is the real closing time of the OR k on the day t
@variable(m,Crev[1:T], Int)
#Crev[t] is the real closing time of the recovery room on the day t
@variable(m,z,Int)
#z is an upper bound of the demand for beds per day in the ICU
@variable(m,OTope[1:T,1:K],Int)
#thie variable represents the overtime of the operating room k on the day t
@variable(m,OTrev[1:T],Int)
#thie variable represents the overtime of the recovery room on the day t

##########OBJECTIVE(S)##########
α = 1 #coefficient related to the total amount of interventions performed
β = 1 #coefficient related to the overtime in the OR
μ = 1 #coefficient related to the overtime in the recovery room
ϵ = 1 #coefficient related to the minimization of the maximal demand for beds per day in the ICU

@objective(m, :Max, α*sum{x[i,t,k]*d[i], i = 1:I, t = 1:T, k = 1:K}
                    - β*sum{OTope[t,k], t = 1:T, k = 1:K}
                    - μ*sum{OTrev[t], t = 1:T}
                    - ϵ*z)

# the objective function aims to:
# - maximize the total amount of time of surgeries performed during the weeksum{getvalue(x)[1,1,k], k = 1:K} - θ[1]
# - minimize the overtime performed in the ORs
# - minimize the overtime performed in the recovery room
# - minimize the maximal demand for beds per day in the ICU

##########CONSTRAINTS##########
@constraint(m, surgeonAvailable[c=1:C,t=1:T], sum{r[c,t,k], k = 1:K} <= o[c,t])
#if the surgeon c is not available on the day t, he won't be assigend to any room (2)

@constraint(m, maxSurgeonByRoomByDay[t=1:T,k=1:K], sum{r[c,t,k], c = 1:C} <= 1)
#there can be at most one surgeon assigned to each room per day (3)

@constraint(m, checkIfCorrectSpecialty[c=1:C,t=1:T,k=1:K], r[c,t,k] <= sum{q[c,s]*a[s,t,k], s= 1:S})
#the surgeon c can be assigned to the OR k on the day t iff it is allocated to his specialty s (4)
#This constraint is correct since r[c,t,k] is a binary variable (it allows a surgeon to have
#more than one specialty)

@constraint(m,checkIfCorrectSurgeon[c=1:C,t=1:T,k=1:K],sum{x[i,t,k], i = 1:I; b[i,c] == 1} <= I*r[c,t,k])
#if the OR k is not allocated to the surgeon c on the day t, none of his patients can be scheduled (5)

@constraint(m, patientOneTime[i=1:I], sum{x[i,t,k], t = 1:T, k = 1:K} <= 1)
#a patient can be scheduled at most one time during the week (6)

@constraint(m, iBeforeJOR[i=1:I,j=1:I], h[i] + d[i] <= h[j] + M*(1-λ[i,j]))
#if the patient j is scheduled after the patient i in an OR, his intervention can't start before
#the intervention of the patient i is finished (7)

@constraint(m, iBeforeJRecoveryBed[i=1:I,j=1:I], (h[i] + d[i]) + dr[i] <= (h[j] + d[j]) + M*(1-ν[i,j]))
#if the patient j is scheduled after the patient i in a recovery bed, his intervention can't finish before
#the patient i is awake in the recovery room (12)

@constraint(m, orderOR[i=1:I,j=1:I,t=1:T,k=1:K; j>i], λ[i,j]+λ[j,i] >= x[i,t,k] + x[j,t,k] -1)
#if the patients i and j are scheduled the same day in the same OR then
#either i precedes j or j precedes i in the OR (8)

@constraint(m, orderRecoveryBed[i=1:I,j=1:I,t=1:T,l=1:L; j>i], ν[i,j]+ν[j,i] >= v[i,t,l] + v[j,t,l] -1)
#if the patients i and j are scheduled the same day in the same recovery bed then
#either i precedes j or j precedes i (13)

@constraint(m, endOfTheLastSurgery[i=1:I,t=1:T,k=1:K],h[i] + d[i] - M*(1-x[i,t,k]) <= Cope[t,k])
#Cope[t,k] represents the end of the last surgery that day in that room and is therefore greater than
#the latest (9)

@constraint(m, lastBedOfTheRecoveryRoom[i=1:I,t=1:T], h[i]+d[i]+dr[i]-M*(1-sum{v[i,t,l], l = 1:L}) <= Crev[t])
#Crev[t] represents the hour of awakening of the last patient in the recovery room that day and is therefore
#greater than the latest (14)

@constraint(m, assignToRecoveryBed[i=1:I,t=1:T], sum{v[i,t,l], l = 1:L} >= sum{x[i,t,k], k = 1:K} - θ[i])
#if the patient i is operated on the day t and he does not need to go in the ICU then
#he must be assigned to a recovery bed on the same day else he's not assigned to
#any recovery bed (17)

@constraint(m, maxRecoveryBed[i=1:I], sum{v[i,t,l], t=1:T, l=1:L} <= 1)
#at most one recovery bed can be assign to each patient during the planification week (18)

@constraint(m, iNeedsIcuOnDayT[i=1:I,t=1:T], γ[i,t] == θ[i]*sum{x[i,tprime,k], k = 1:K, tprime = max(1,t-δ[i]+1):t})
#γ[i,t] = 1 if the patient i occupies a bed in the ICU on the day t (19)

@constraint(m, ressourcesBedIcu[t=1:T], sum{γ[i,t], i = 1:I} <= Ω)
#each day, the resources in beds in the ICU can't be exceeded (20)

@constraint(m, maxDemandICU[t=1:T], z >= sum{γ[i,t], i = 1:I})
#z is an upper bound of the demand for the beds each day (21)

@constraint(m, minICUIntervention, sum{x[i,t,k], i = 1:I, t = 1:T, k = 1:K; θ[i] == 1} >= sum{θ[i],i=1:I}/2)
#at least half of the patient needing the ICU must be operated

@constraint(m, overtimeOpe[t=1:T,k=1:K], OTope[t,k] >= 0) #(10)
@constraint(m, overtimeOpe[t=1:T,k=1:K], OTope[t,k] >= Cope[t,k] - Fope) #(11)
#OTope[t,k] = max(0;Cope[t,k]-Fope)

@constraint(m, overtimeRec[t=1:T], OTrev[t] >= 0) #(15)
@constraint(m, overtimeOpe[t=1:T], OTrev[t] >= Crev[t] - Frev) #(15)
#OTrev[t,k] = max(0;Crev[t,k]-Frev)

function displayResults()

  jours = ["lundi","mardi","mercredi","jeudi","vendredi"]
  for t = 1:T
    println("**********", jours[t], "**********")
    println()
    for k = 1:K
      chir = -1
      spe = -1
      for c = 1:C
        if (getvalue(r)[c,t,k] > 0.95)
          chir = c
        end
      end
      for s = 1:S
        if (a[s,t,k] == 1)
          spe = s
        end
      end
      println("------ salle ", k, "------- (chir ", chir,",spe ", spe, ")")
      for i = 1:I
        if (getvalue(x)[i,t,k] == 1)
          recoveryBed = -1
          for l in 1:L
            if (getvalue(v)[i,t,l] == 1)
              recoveryBed = l
            end
          end
          print("patient ", i, " de ", getvalue(h)[i], " h à ", getvalue(h)[i]+d[i], " h ")
          if recoveryBed > 0
            println("(lit de recup n ", recoveryBed, " de, ", getvalue(h)[i]+d[i], " à ", getvalue(h)[i]+d[i]+dr[i],")")
          else
            println("(lit ICU du jour ", t, " au jour ", Int32(t+δ[i]-1), " inclus)")
          end
        end
      end
      println()
    end
    println()
  end

  for t = 1:T
    demand = 0
    totalScheduled = 0
    for i = 1:I
      demand = demand + getvalue(γ)[i,t]
    end
    println("demand for the ICU beds on day ", Int32(t), ":", demand)
  end

end

function displayCaracteristics()
  println("Number of patients who had their surgery performed : ", sum(getvalue(x)))

  for k = 1:K
    totalWeekAmountSur = 0
    for t = 1:T
      totalAmountOfSurgery = 0
      overtime = 0
      for i = 1:I
        if (getvalue(x)[i,t,k] > 0.95)
          if (getvalue(h)[i] + d[i] <= 480)
            totalAmountOfSurgery = totalAmountOfSurgery + d[i]
          else
            totalAmountOfSurgery = totalAmountOfSurgery + 480 - getvalue(h)[i]
            overtime = getvalue(h)[i] + d[i] - 480
          end
        end
      end
      println("Day ",t, ", room ", k, " --> amount of surgery performed in the opening hours : ", totalAmountOfSurgery)
      totalWeekAmountSur = totalWeekAmountSur + totalAmountOfSurgery
    end
    println("Room ", k, " total over the week : ", totalWeekAmountSur, "(", 100*totalWeekAmountSur/(5*480), "%)")
  end

  numICUPatient = sum(θ)
  numICUPatient_ope = 0
  for i = 1:I

    if (sum(getvalue(x)[i,:,:]) > 0.95 && θ[i] == 1)
      numICUPatient_ope += 1
    end
  end

  println("Number of ICU patients operated : ", numICUPatient_ope, "/", numICUPatient)

end
