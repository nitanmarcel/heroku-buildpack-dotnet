# Heroku .NET Core Buildpack

This is the [Heroku buildpack](https://devcenter.heroku.com/articles/buildpacks) for [.NET Core](https://docs.microsoft.com/en-us/dotnet/).

The Buildpack supports C# .Net Core Console applications. It searchs through the repository's folders to locate a `Program.cs` and `.csproj` files. Make sure these are available. 

## Usage

heroku buildpacks:set https://github.com/nitanmarcel/heroku-buildpack-dotnet.git
