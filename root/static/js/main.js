function AddTableRowToolbar( $toolbar, $table, $rows ) {
    $rows.mouseenter(function(){
        $toolbar.slideDown().position({
            of: $(this),
            my: "left top",
            at: "left bottom",
        });
        window.selected_id = $(this).attr("id");
    });
    
}

function isToday() {
    var date = new Date();
    var dateTime=document.getElementById("datepicker");
    var nowMonth = date.getMonth() + 1;
    var strDate = date.getDate();
    var seperator = "-";
    if (nowMonth >= 1 && nowMonth <= 9) {
        nowMonth = "0" + nowMonth;
    }
    if (strDate >= 0 && strDate <= 9) {
        strDate = "0" + strDate;
    }
    var nowDate = date.getFullYear() + seperator + nowMonth + seperator + strDate;
    if(nowDate==dateTime.value)
        return true;
    else
        return false;
}

function setHour() {
    $("#reservation-hour").empty();
    var selecthour = document.getElementById("reservation-hour");
    var hours = ["00", "01", "02", "03", "04" , "05", "06", "07", "08", "09", "10", "11", "12",      "13", "14" , "15", "16", "17", "18", "19", "20", "21", "22", "23"];
    var date = new Date();
    var minute = date.getMinutes();
    var i=0;
    if(isToday()) {
        i=date.getHours();
        if(minute>=55){
            i=i+1;
        }
    }
    for(i;i<hours.length;i++)
    {
        var opt = hours[i];
        var el = document.createElement("option");
        el.textContent = opt;
        el.value = opt;
        selecthour.appendChild(el);
    }
}

function setMinute() {
    $("#reservation-minute").empty();
    var selectminute = document.getElementById("reservation-minute");
    var selecthour = document.getElementById("reservation-hour");
    var minutes = ["00", "05", "10", "15", "20" , "25", "30", "35", "40", "45", "50", "55"];
    var i=0;
    var date = new Date();
    var hour=date.getHours();

    if (hour<= 9) {
        hour = "0" + hour;
    }

    if(isToday() && hour==selecthour.value){
        i=parseInt(date.getMinutes()/5)+1;
    }

    for(i;i<minutes.length;i++)
    {
        var opt = minutes[i];
        var el = document.createElement("option");
        el.textContent = opt;
        el.value = opt;
        selectminute.appendChild(el);
    }
}

function setTime() {
    setHour();
    setMinute();
}
