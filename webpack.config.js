var path = require('path');
var webpack = require('webpack');
var autoprefixer = require('autoprefixer');
var precss = require('precss');
var functions = require('postcss-functions');
var ExtractTextPlugin = require('mini-css-extract-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');

var postCssLoader = [
    'css-loader?modules',
    '&localIdentName=[name]__[local]___[hash:base64:5]',
    '&disableStructuralMinification',
    '!postcss-loader'
];

var plugins = [
    new CleanWebpackPlugin(),
    new ExtractTextPlugin('bundle.css'),
];

if (process.env.NODE_ENV === 'production') {
    plugins = plugins.concat([
        new webpack.optimize.UglifyJsPlugin({
            output: {comments: false},
            test: /bundle\.js?$/
        }),
        new webpack.DefinePlugin({
            'process.env': {NODE_ENV: JSON.stringify('production')}
        })
    ]);

    postCssLoader.splice(1, 1); // drop human readable names
} else {
    plugins = plugins.concat([
        new webpack.DefinePlugin({
            'process.env': {NODE_ENV: JSON.stringify('development')}
        })
    ]);
}

var config = {
    entry: {
        bundle: path.join(__dirname, 'client/index.jsx')
    },
    output: {
        path: path.join(__dirname, 'dist'),
        publicPath: '/dist/',
        filename: '[name].js'
    },
    optimization: {
        noEmitOnErrors: true
    },
    plugins: plugins,
    module: {
        rules:
            [
                {
                    test: /\.jsx?$/,
                    exclude: /(node_modules)/,
                    use: [
                        {
                            loader: 'babel-loader'
                        }
                    ]
                },
                {
                    test: /\.css$/,
                    use: ['style-loader', 'css-loader']
                }
            ]
    },
    resolve: {
        extensions: ['.js', '.jsx', '.css'],
        alias: {
            '#app': path.join(__dirname, 'client'),
            '#c': path.join(__dirname, 'client/components'),
            '#css': path.join(__dirname, 'client/css')
        }
    }
};

module.exports = config;
