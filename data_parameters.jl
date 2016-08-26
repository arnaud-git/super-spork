using DataFrames

waiting_list = convert(Array,readtable("waiting_list_90_surg_600_patients.csv", separator = ',', header = true))
I = 400 #Patients i
waiting_list = waiting_list[1:I,:]
surgeons_spe_and_availability = convert(Array,readtable("surgeons_specialty_and_availability_90_surg_10_spe.csv", separator=',', header=true))
MSS = convert(Array,readtable("MSS_10_rooms_10_spe.csv", separator=',', header=true))
MSS = MSS[:,2:size(MSS,2)] #withdraw the first column containing the numbers of the rooms
##########PARAMETERS##########
M = 500 #Big-M value (to be tuned) #M should be equal to 480 + max(d[i], i in I)
T = 5 #Days t in the week
L = 15 #Beds l in the recovery room
Ω = 15 # Number of beds available in the ICU

C = size(surgeons_spe_and_availability, 1) #Surgeons c
S = maximum(surgeons_spe_and_availability[:,2]) #Specialties s
K = size(MSS,1) #Operating rooms k

d = waiting_list[1:I,3]
#d[i] is the duration of the intervention of the patient i
dr = waiting_list[1:I,4]
#dr[i] is the duration of the recovery of the patient i
δ = waiting_list[1:I,5]
#δ[i] represents the number of days needed in the ICU
a = zeros(S,T,K)
for t = 1:T
  for k = 1:K
    a[MSS[k,t],t,k] = 1
  end
end
#a[s,t,k] = 1 if the OR k is allocated to the specialty s on the day t, 0 otherwise

o = surgeons_spe_and_availability[:,3:size(surgeons_spe_and_availability,2)]
#o[c,t] = 1 if the surgeon c is available on the day t, 0 otherwise
q = zeros(C,S)
spe = surgeons_spe_and_availability[:,2]
for c = 1:C
  q[c,spe[c]] = 1
end
#q[c,s] = 1 if the surgeon c belongs to the specialty s, 0 otherwise

b = zeros(I,C)
for i = 1:I
  surgeon = waiting_list[i,2]
  b[i,surgeon]=1
end
#b[i,c] = 1 if the patient i belongs to the waiting list of the surgeon c, 0 otherwise
θ = zeros(I)
for i = 1:I
  if δ[i] > 0
    θ[i] = 1
  end
end
#θ[i] = 1 if the patient i needs to go to the ICU c, 0 otherwise

Fope = 480
#Fope is the official closing time of the OR
Frev = 480
#Frev is the official closing time of the recovery room
