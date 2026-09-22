const { HttpError, integer, documentId } = require('./validation');

async function page(collection, query = {}, sortField = null, direction = 'desc') {
    const limit = integer(query.limit ?? 30, 'Limite', 1, 100);
    let request = sortField
        ? collection.orderBy(sortField, direction).orderBy('__name__', direction)
        : collection.orderBy('__name__');
    if (query.cursor) {
        const cursor = await collection.doc(documentId(query.cursor)).get();
        if (!cursor.exists) throw new HttpError(400, 'El cursor ya no existe. Actualiza la lista.');
        request = request.startAfter(cursor);
    }
    const snapshot = await request.limit(limit + 1).get();
    const hasMore = snapshot.docs.length > limit;
    const docs = snapshot.docs.slice(0, limit);
    return { docs, next_cursor: hasMore ? docs[docs.length - 1].id : null };
}

module.exports = { page };
