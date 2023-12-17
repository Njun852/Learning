const express = require('express')
const {products} = require('./data')
const app = express()

app.get('/', (req, res) => {
    res.send('<h1>Homepage</h1> <a href="/api/products">products</a>')
})
app.get('/api/products/:productID', (req, res) => {
    const {productID} = req.params
    const product = products.find(product => product.id === Number(productID))
    if(!productID || !product){
        return res.status(404).send('Not found')
    }
    return res.send(product)
})

app.get('/api/v1/query', (req, res) => {
    
    const {search, limit} = req.query

    let filteredProduct = [...products]

    if(search){
        filteredProduct = filteredProduct
        .filter(product => product.name.startsWith(search))
    }
    if(limit){
        filteredProduct = filteredProduct.splice(0, Number(limit))
    }
    if(filteredProduct.length < 1){
        return res.status(200)
        .json({success: true, data: []})
    }
    res.status(200)
    .json({success: true, data: filteredProduct})
})

app.listen(5000, () => console.log("listening on port 5000..."))