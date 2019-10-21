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

