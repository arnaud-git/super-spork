type tPatient
  id
  scheduled
  day
  room
  begin_sur
  end_sur
  recovery_bed
  begin_rec
  end_rec
  ICU
  begin_icu
  end_icu

  function tPatient(id,x,v,h,d_i,dr_i,δ_i)

    id #useless?
    scheduled = -1
    day = -1
    room = -1
    begin_sur = -1
    end_sur = -1
    recovery_bed = -1
    begin_rec = -1
    end_rec = -1
    ICU = -1
    begin_icu = -1
    end_icu = -1

    for t = 1:T
      for k = 1:K

        if x[id,t,k] == 1

          scheduled = 1
          day = t
          room = k
          begin_sur = h[id]
          end_sur = h[id] + d_i

          if δ_i > 0 #if the patient need to be admitted at the ICU
            ICU = 1
            begin_icu = day
            end_icu = day + δ_i - 1 #this line has been modified since its last upload
          else
            for l = 1:L
              if v[id,t,l] == 1
                recovery_bed = l
                break
              end
            end

            begin_rec = h[id] + d_i #the beginning of the recovery corresponds to the end of surgery
            end_rec = h[id] + d_i + dr_i
          end

          break

        end

      end
    end

    if scheduled == -1
      new(id,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1)
    else
      new(id,scheduled,day,room,begin_sur,end_sur,recovery_bed,begin_rec,end_rec,ICU,begin_icu,end_icu)
    end

  end
end

type tRoom

  id
  schedule::Array{Int32,2}

  function tRoom(id, list_of_patients, numDays)
    sch = Array(Int32,(0,2))
    for t = 1:numDays
      for i = 1:length(list_of_patients)
        p = list_of_patients[i]
        if (p.scheduled == 1 && p.day == t && p.room == id)
          sch = vcat(sch,[t p.id])
        end
      end
    end
    new(id,sch)
  end
end

type tRecoveryBed

  id
  schedule::Array{Int32,2}

  function tRecoveryBed(id, list_of_patients, numDays)
    sch = Array(Int32,(0,2))
    for t = 1:numDays
      for i = 1:length(list_of_patients)
        p = list_of_patients[i]
        if (p.scheduled == 1 && p.day == t && p.recovery_bed == id)
          sch = vcat(sch,[t p.id])
        end
      end
    end
    new(id,sch)
  end
end


list_of_patients = tPatient[]
for i = 1:I
  p = tPatient(i,getvalue(x),getvalue(v),getvalue(h),d[i],dr[i],δ[i])
  push!(list_of_patients,p)
end

list_of_rooms = tRoom[]
for k = 1:K
  push!(list_of_rooms,tRoom(k,list_of_patients,T))
end

list_of_recovery_beds = tRecoveryBed[]
for l = 1:L
  push!(list_of_beds,tRecoveryBed(l,list_of_patients,T))
end

schedule_room_file = open("schedule_room_file.txt","w")

for l = 1:size(list_of_rooms[1].schedule,1)
  day = list_of_rooms[1].schedule[l,1]
  patient_id = list_of_rooms[1].schedule[l,2]
  write(schedule_room_file, string(day, ";", patient_id, ";", list_of_patients[patient_id].begin_sur, ";", list_of_patients[patient_id].end_sur, "\n"))
end

close(schedule_room_file)
