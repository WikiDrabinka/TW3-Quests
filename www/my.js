function select_quest_on_click(table) {
    table.on('click','tr',function(){
        if ($(this).hasClass('selected')){
            $(this).removeClass('selected')
            $(this).siblings().removeClass('selected')
            Shiny.setInputValue('questID', parseInt($(this).children()[0].textContent), { priority: 'event' })
        }
    })
}

function select_next(rowInfo, column) {
    if (column.id !== 'Name') {
        return
    }
    Shiny.setInputValue('questID', rowInfo.original.ID, { priority: 'event' })
}